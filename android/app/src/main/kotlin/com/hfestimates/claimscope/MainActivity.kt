package com.hfestimates.claimscope

import android.net.Uri
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingProgramAvailabilityDetails
import com.android.billingclient.api.BillingProgramAvailabilityListener
import com.android.billingclient.api.BillingProgramReportingDetails
import com.android.billingclient.api.BillingProgramReportingDetailsListener
import com.android.billingclient.api.BillingProgramReportingDetailsParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.EnableBillingProgramParams
import com.android.billingclient.api.LaunchExternalLinkParams
import com.android.billingclient.api.LaunchExternalLinkResponseListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.hfestimates.claimscope/external_content_links"
        private val EXTERNAL_CONTENT_LINK_PROGRAM =
            BillingClient.BillingProgram.EXTERNAL_CONTENT_LINK
    }

    private lateinit var billingClient: BillingClient
    private var externalLinkPreparationInProgress = false
    private var externalLinkLaunchInProgress = false
    private var pendingExternalTransactionToken: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val billingProgramParams = EnableBillingProgramParams.newBuilder()
            .setBillingProgram(EXTERNAL_CONTENT_LINK_PROGRAM)
            .build()

        billingClient = BillingClient.newBuilder(this)
            .enableBillingProgram(billingProgramParams)
            .enableAutoServiceReconnection()
            .build()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareExternalCheckout" -> prepareExternalCheckout(result)

                "launchExternalCheckout" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error(
                            "INVALID_EXTERNAL_LINK",
                            "The Stripe Checkout URL is missing.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    launchPreparedExternalCheckout(url, result)
                }

                "discardExternalCheckoutPreparation" -> {
                    discardExternalCheckoutPreparation()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun prepareExternalCheckout(result: MethodChannel.Result) {
        if (
            externalLinkPreparationInProgress ||
            externalLinkLaunchInProgress ||
            pendingExternalTransactionToken != null
        ) {
            result.error(
                "EXTERNAL_LINK_IN_PROGRESS",
                "An external checkout is already being prepared.",
                null,
            )
            return
        }

        externalLinkPreparationInProgress = true
        ensureBillingClientReady(result) {
            checkExternalContentLinkAvailability(result)
        }
    }

    private fun ensureBillingClientReady(
        result: MethodChannel.Result,
        onReady: () -> Unit,
    ) {
        if (billingClient.isReady) {
            onReady()
            return
        }

        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    onReady()
                } else {
                    finishWithBillingError(
                        result,
                        "PLAY_BILLING_CONNECTION_FAILED",
                        billingResult,
                    )
                }
            }

            override fun onBillingServiceDisconnected() {
                // Auto service reconnection is enabled. If setup does not complete,
                // the next checkout attempt will retry the connection.
            }
        })
    }

    private fun checkExternalContentLinkAvailability(result: MethodChannel.Result) {
        billingClient.isBillingProgramAvailableAsync(
            EXTERNAL_CONTENT_LINK_PROGRAM,
            object : BillingProgramAvailabilityListener {
                override fun onBillingProgramAvailabilityResponse(
                    billingResult: BillingResult,
                    billingProgramAvailabilityDetails: BillingProgramAvailabilityDetails,
                ) {
                    if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                        finishWithBillingError(
                            result,
                            "EXTERNAL_CONTENT_LINK_UNAVAILABLE",
                            billingResult,
                        )
                        return
                    }

                    createExternalTransactionToken(result)
                }
            },
        )
    }

    private fun createExternalTransactionToken(result: MethodChannel.Result) {
        val reportingParams = BillingProgramReportingDetailsParams.newBuilder()
            .setBillingProgram(EXTERNAL_CONTENT_LINK_PROGRAM)
            .build()

        billingClient.createBillingProgramReportingDetailsAsync(
            reportingParams,
            object : BillingProgramReportingDetailsListener {
                override fun onCreateBillingProgramReportingDetailsResponse(
                    billingResult: BillingResult,
                    billingProgramReportingDetails: BillingProgramReportingDetails?,
                ) {
                    if (
                        billingResult.responseCode != BillingClient.BillingResponseCode.OK ||
                        billingProgramReportingDetails == null
                    ) {
                        finishWithBillingError(
                            result,
                            "EXTERNAL_TRANSACTION_TOKEN_FAILED",
                            billingResult,
                        )
                        return
                    }

                    pendingExternalTransactionToken =
                        billingProgramReportingDetails.externalTransactionToken
                    externalLinkPreparationInProgress = false
                    result.success(true)
                }
            },
        )
    }

    private fun launchPreparedExternalCheckout(
        url: String,
        result: MethodChannel.Result,
    ) {
        if (externalLinkPreparationInProgress || externalLinkLaunchInProgress) {
            result.error(
                "EXTERNAL_LINK_IN_PROGRESS",
                "An external checkout is already being prepared.",
                null,
            )
            return
        }

        val externalTransactionToken = pendingExternalTransactionToken
        if (externalTransactionToken.isNullOrBlank()) {
            result.error(
                "EXTERNAL_TRANSACTION_TOKEN_MISSING",
                "Google Play checkout preparation is required before opening Stripe Checkout.",
                null,
            )
            return
        }

        val uri = try {
            Uri.parse(url)
        } catch (_: Exception) {
            null
        }

        if (uri == null || uri.scheme != "https") {
            pendingExternalTransactionToken = null
            result.error(
                "INVALID_EXTERNAL_LINK",
                "The checkout link must use HTTPS.",
                null,
            )
            return
        }

        // Consume the token before the launch attempt so it can never be reused.
        pendingExternalTransactionToken = null
        externalLinkLaunchInProgress = true

        ensureBillingClientReady(result) {
            launchExternalContentLink(
                uri,
                externalTransactionToken,
                result,
            )
        }
    }

    private fun launchExternalContentLink(
        uri: Uri,
        externalTransactionToken: String,
        result: MethodChannel.Result,
    ) {
        val params = LaunchExternalLinkParams.newBuilder()
            .setBillingProgram(EXTERNAL_CONTENT_LINK_PROGRAM)
            .setLinkUri(uri)
            .setLinkType(LaunchExternalLinkParams.LinkType.LINK_TO_DIGITAL_CONTENT_OFFER)
            .setLaunchMode(
                LaunchExternalLinkParams.LaunchMode.LAUNCH_IN_EXTERNAL_BROWSER_OR_APP,
            )
            .setExternalTransactionToken(externalTransactionToken)
            .build()

        billingClient.launchExternalLink(
            this,
            params,
            object : LaunchExternalLinkResponseListener {
                override fun onLaunchExternalLinkResponse(billingResult: BillingResult) {
                    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                        externalLinkLaunchInProgress = false
                        result.success(true)
                    } else {
                        finishWithBillingError(
                            result,
                            "EXTERNAL_CONTENT_LINK_FAILED",
                            billingResult,
                        )
                    }
                }
            },
        )
    }

    private fun discardExternalCheckoutPreparation() {
        if (!externalLinkLaunchInProgress) {
            externalLinkPreparationInProgress = false
            pendingExternalTransactionToken = null
        }
    }

    private fun resetExternalCheckoutState() {
        externalLinkPreparationInProgress = false
        externalLinkLaunchInProgress = false
        pendingExternalTransactionToken = null
    }

    private fun finishWithBillingError(
        result: MethodChannel.Result,
        code: String,
        billingResult: BillingResult,
    ) {
        resetExternalCheckoutState()
        result.error(
            code,
            billingResult.debugMessage.ifBlank {
                "Google Play could not start the external checkout flow."
            },
            mapOf("responseCode" to billingResult.responseCode),
        )
    }

    override fun onDestroy() {
        resetExternalCheckoutState()
        if (::billingClient.isInitialized) {
            billingClient.endConnection()
        }
        super.onDestroy()
    }
}
