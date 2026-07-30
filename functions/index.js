// 1. IMPORTS
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");
const Stripe = require("stripe");
const nodemailer = require("nodemailer");
const crypto = require("crypto");

// 2. INICIALIZACIÓN (Solo una vez)
admin.initializeApp();

// 3. CONFIGURACIÓN Y SECRETOS
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const webhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
const emailPass = defineSecret("EMAIL_PASS");

const priceBasicMonthly = defineString("STRIPE_PRICE_BASIC_MONTHLY", {
    default: "price_1TuUwQIV8TkU9SxHrb9ieW5i"
});
const priceBasicYearly = defineString("STRIPE_PRICE_BASIC_YEARLY", {
    default: "price_1TuUwuIV8TkU9SxHqloMd4cx"
});
const pricePremiumMonthly = defineString("STRIPE_PRICE_PREMIUM_MONTHLY", {
    default: "price_1TuV4BIV8TkU9SxHdeD5Z1Y2"
});
const pricePremiumYearly = defineString("STRIPE_PRICE_PREMIUM_YEARLY", {
    default: "price_1TuV4cIV8TkU9SxHvtciIczy"
});

const CHECKOUT_SUCCESS_URL = "claimscope://success";
const CHECKOUT_CANCEL_URL = "claimscope://cancel";
const STRIPE_WEBHOOK_EVENTS_COLLECTION = "stripeWebhookEvents";
const STRIPE_WEBHOOK_LOCK_TIMEOUT_MS = 10 * 60 * 1000;

function normalizeSubscriptionPlan(value) {
  const plan = String(value || "").trim().toLowerCase();
  return plan === "basic" || plan === "premium" ? plan : null;
}

function normalizeBillingPeriod(value) {
  const billingPeriod = String(value || "").trim().toLowerCase();
  return billingPeriod === "monthly" || billingPeriod === "yearly"
    ? billingPeriod
    : null;
}

function resolveSubscriptionPriceId(plan, billingPeriod) {
  if (plan === "basic") {
    return billingPeriod === "yearly"
      ? priceBasicYearly.value()
      : priceBasicMonthly.value();
  }

  return billingPeriod === "yearly"
    ? pricePremiumYearly.value()
    : pricePremiumMonthly.value();
}

function resolveSubscriptionSelectionFromPriceId(priceId) {
  if (priceId === priceBasicMonthly.value()) {
    return { plan: "basic", billingPeriod: "monthly" };
  }
  if (priceId === priceBasicYearly.value()) {
    return { plan: "basic", billingPeriod: "yearly" };
  }
  if (priceId === pricePremiumMonthly.value()) {
    return { plan: "premium", billingPeriod: "monthly" };
  }
  if (priceId === pricePremiumYearly.value()) {
    return { plan: "premium", billingPeriod: "yearly" };
  }
  return null;
}

// Resuelve el plan ('basic' | 'premium') únicamente para Price IDs autorizados.
function resolvePlanFromPriceId(priceId) {
  if (priceId === pricePremiumMonthly.value() || priceId === pricePremiumYearly.value()) {
    return "premium";
  }
  if (priceId === priceBasicMonthly.value() || priceId === priceBasicYearly.value()) {
    return "basic";
  }
  return null;
}

function requirePaidPlanFromAuth(auth) {
  const plan = normalizeSubscriptionPlan(auth?.token?.plan);
  if (!plan) {
    throw new HttpsError(
      "permission-denied",
      "An active Basic or Premium plan is required."
    );
  }
  return plan;
}

// Newer configuration for nodemailer using Gmail

function sanitizeAttachmentFilename(input, fallback) {
  const s = String(input || "").trim();
  if (!s) return fallback;
  return s.replace(/[\\/\:\*\?"<>\|]/g, "").trim() || fallback;
}

function buildHfReportKey(userId, claimNumber, address, dateInspected) {
  const raw = [userId || "", claimNumber || "", address || "", dateInspected || ""].join("|");
  return crypto.createHash("sha256").update(raw).digest("hex");
}

function hasNonEmptyValue(value) {
  if (value === null || value === undefined) return false;
  if (typeof value === "string") return value.trim().length > 0;
  if (typeof value === "boolean") return value === true;
  if (typeof value === "number") return Number.isFinite(value) && value !== 0;
  if (Array.isArray(value)) return value.some(hasNonEmptyValue);
  if (typeof value === "object") return Object.values(value).some(hasNonEmptyValue);
  return false;
}

function elevationEntryHasAnyData(entry) {
  if (!entry || typeof entry !== "object") return false;
  return Object.entries(entry).some(([key, value]) => {
    if (key === "side") return false;
    return hasNonEmptyValue(value);
  });
}

function hasChargeableElevationDetailsFromReport(report) {
  const elevations = report?.elevations?.elevations;
  if (!Array.isArray(elevations)) return false;
  return elevations.some(elevationEntryHasAnyData);
}

function applyPlanDiscount(total, plan) {
  if (plan === "basic") return total * 0.90;
  if (plan === "premium") return total * 0.85;
  return total;
}

function isMissingStripeResource(error) {
  return error?.code === "resource_missing";
}

async function deleteStripeAccountData(stripeClient, customClaims) {
  const customerId = customClaims?.stripeCustomerId;
  const subscriptionId = customClaims?.subscriptionId;

  if (typeof customerId === "string" && customerId.length > 0) {
    try {
      await stripeClient.customers.del(customerId);
    } catch (error) {
      if (!isMissingStripeResource(error)) throw error;
    }
    return;
  }

  if (typeof subscriptionId === "string" && subscriptionId.length > 0) {
    try {
      await stripeClient.subscriptions.cancel(subscriptionId);
    } catch (error) {
      if (!isMissingStripeResource(error)) throw error;
    }
  }
}

function calculateResidentialBasePrice(report) {
  let total = 70;
  if (report?.hasShed) total += 10;
  if (report?.hasDetachedStructure) total += 15;
  return total;
}

function calculateCommercialBasePrice(report) {
  const buildings = Array.isArray(report?.commercialBuildings) ? report.commercialBuildings : [];
  if (buildings.length === 0 || buildings.length >= 4) return null;

  let total = 100;
  for (const building of buildings) {
    const roofSections = Array.isArray(building?.roofs) ? building.roofs.length : 0;
    if (roofSections >= 4) total += 120;
    else if (roofSections > 0) total += roofSections * 30;
  }

  if (buildings.length > 1) total += (buildings.length - 1) * 50;
  return total;
}


function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function resolveLegacyExtraEmail(auth, requestedEmails) {
  if (!Array.isArray(requestedEmails)) return null;

  const accountEmail = normalizeEmail(auth?.token?.email);
  const uniqueEmails = [...new Set(
    requestedEmails
      .map(normalizeEmail)
      .filter((email) => email.length > 0)
  )];
  const additionalEmails = uniqueEmails.filter((email) => email !== accountEmail);

  if (additionalEmails.length > 1) {
    throw new HttpsError(
      "invalid-argument",
      "Only one additional email address is allowed."
    );
  }
  return additionalEmails[0] || null;
}

function resolveInspectionEmailRecipients(auth, requestedExtraEmail) {
  const plan = requirePaidPlanFromAuth(auth);
  const accountEmail = normalizeEmail(auth?.token?.email);

  if (!accountEmail || !isValidEmail(accountEmail)) {
    throw new HttpsError(
      "failed-precondition",
      "The authenticated account does not have a valid email address."
    );
  }

  const extraEmail = normalizeEmail(requestedExtraEmail);
  if (!extraEmail) return [accountEmail];

  if (!isValidEmail(extraEmail)) {
    throw new HttpsError("invalid-argument", "The additional email address is invalid.");
  }

  if (plan !== "premium") {
    throw new HttpsError(
      "permission-denied",
      "Sending reports to an additional email requires Premium."
    );
  }

  return extraEmail === accountEmail
    ? [accountEmail]
    : [accountEmail, extraEmail];
}

function decodeUrlComponent(value) {
  try {
    return decodeURIComponent(value);
  } catch (_) {
    throw new HttpsError("invalid-argument", "Invalid Firebase Storage URL.");
  }
}

function validateUserPdfDownloadUrl(rawUrl, userId, mode, expectedFilename) {
  let parsed;
  try {
    parsed = new URL(String(rawUrl || ""));
  } catch (_) {
    throw new HttpsError("invalid-argument", "Invalid Firebase Storage URL.");
  }

  if (parsed.protocol !== "https:" || parsed.hostname !== "firebasestorage.googleapis.com") {
    throw new HttpsError(
      "permission-denied",
      "Report files must be stored in ClaimScope Firebase Storage."
    );
  }

  const segments = parsed.pathname.split("/").filter(Boolean);
  if (
    segments.length < 5 ||
    segments[0] !== "v0" ||
    segments[1] !== "b" ||
    segments[3] !== "o"
  ) {
    throw new HttpsError("invalid-argument", "Invalid Firebase Storage download URL.");
  }

  const bucketName = decodeUrlComponent(segments[2]);
  const expectedBucketName = admin.storage().bucket().name;
  if (bucketName !== expectedBucketName) {
    throw new HttpsError(
      "permission-denied",
      "The report file belongs to a different Firebase Storage bucket."
    );
  }

  const objectPath = decodeUrlComponent(segments.slice(4).join("/"));
  const userPrefix = `temp_reports/${userId}/`;
  if (!objectPath.startsWith(userPrefix)) {
    throw new HttpsError(
      "permission-denied",
      "The report file does not belong to the authenticated user."
    );
  }

  const relativeSegments = objectPath.slice(userPrefix.length).split("/");
  const hasNumericTimestamp = (value) => /^\d+$/.test(value || "");

  if (mode === "email") {
    if (
      relativeSegments.length !== 2 ||
      !hasNumericTimestamp(relativeSegments[0]) ||
      relativeSegments[1] !== expectedFilename
    ) {
      throw new HttpsError("permission-denied", "Unexpected report file location.");
    }
  } else if (mode === "hf") {
    if (
      relativeSegments.length !== 3 ||
      relativeSegments[0] !== "hf_orders" ||
      !hasNumericTimestamp(relativeSegments[1]) ||
      relativeSegments[2] !== expectedFilename
    ) {
      throw new HttpsError("permission-denied", "Unexpected HF order file location.");
    }
  } else {
    throw new HttpsError("internal", "Unsupported report validation mode.");
  }

  return objectPath;
}

function validateUserPdfPair(techPdfUrl, photoPdfUrl, userId, mode) {
  const techPath = validateUserPdfDownloadUrl(
    techPdfUrl,
    userId,
    mode,
    "tech.pdf"
  );
  const photoPath = validateUserPdfDownloadUrl(
    photoPdfUrl,
    userId,
    mode,
    "photos.pdf"
  );

  const techDirectory = techPath.slice(0, techPath.lastIndexOf("/"));
  const photoDirectory = photoPath.slice(0, photoPath.lastIndexOf("/"));
  if (techDirectory !== photoDirectory) {
    throw new HttpsError(
      "permission-denied",
      "The technical and photo reports must belong to the same upload."
    );
  }

  return { techPath, photoPath };
}

async function claimStripeWebhookEvent(event) {
  const db = admin.firestore();
  const ref = db.collection(STRIPE_WEBHOOK_EVENTS_COLLECTION).doc(event.id);
  const now = admin.firestore.Timestamp.now();
  const staleBefore = now.toMillis() - STRIPE_WEBHOOK_LOCK_TIMEOUT_MS;

  const state = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() : {};

    if (data?.status === "processed") return "processed";

    const updatedAtMillis = data?.updatedAt?.toMillis?.() || 0;
    if (data?.status === "processing" && updatedAtMillis > staleBefore) {
      return "processing";
    }

    transaction.set(
      ref,
      {
        eventType: event.type,
        status: "processing",
        attempts: Number(data?.attempts || 0) + 1,
        createdAt: data?.createdAt || now,
        updatedAt: now,
      },
      { merge: true }
    );
    return "claimed";
  });

  return { ref, state };
}

async function markStripeWebhookProcessed(ref) {
  await ref.set(
    {
      status: "processed",
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastError: admin.firestore.FieldValue.delete(),
    },
    { merge: true }
  );
}

async function markStripeWebhookFailed(ref, error) {
  await ref.set(
    {
      status: "failed",
      lastError: String(error?.message || error || "Unknown webhook error").slice(0, 1000),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function setSubscriptionClaims(userId, subscription) {
  const priceId = subscription.items.data[0]?.price?.id;
  const plan = resolvePlanFromPriceId(priceId);
  if (!plan) {
    throw new Error(`Unauthorized Stripe Price ID received: ${priceId || "missing"}`);
  }

  try {
    const userRecord = await admin.auth().getUser(userId);
    const customerId = typeof subscription.customer === "string"
      ? subscription.customer
      : subscription.customer?.id;

    await admin.auth().setCustomUserClaims(userId, {
      ...(userRecord.customClaims || {}),
      plan,
      stripeCustomerId: customerId || null,
      subscriptionId: subscription.id,
    });
    console.log(`Plan assigned: ${plan} to ${userId}`);
  } catch (error) {
    if (error?.code === "auth/user-not-found") {
      console.log(`Subscription event received after Firebase user removal: ${userId}`);
      return;
    }
    throw error;
  }
}

async function refreshSubscriptionClaims(stripeClient, subscriptionId) {
  const subscription = await stripeClient.subscriptions.retrieve(subscriptionId, {
    expand: ["items.data.price"],
  });
  const userId = subscription.metadata?.userId;
  if (!userId) {
    throw new Error(`Stripe subscription ${subscription.id} is missing metadata.userId`);
  }
  await setSubscriptionClaims(userId, subscription);
}

async function markSubscriptionDeleted(subscription) {
  const userId = subscription.metadata?.userId;
  if (!userId) return;

  try {
    const userRecord = await admin.auth().getUser(userId);
    const updatedClaims = {
      ...(userRecord.customClaims || {}),
      plan: "free",
      subscriptionId: null,
    };

    const customerId = typeof subscription.customer === "string"
      ? subscription.customer
      : subscription.customer?.id;
    if (!updatedClaims.stripeCustomerId && customerId) {
      updatedClaims.stripeCustomerId = customerId;
    }

    await admin.auth().setCustomUserClaims(userId, updatedClaims);
  } catch (error) {
    if (error?.code === "auth/user-not-found") {
      console.log(`Subscription deleted after Firebase user removal: ${userId}`);
      return;
    }
    throw error;
  }
}

async function processHfCheckoutSession(session, transporter) {
  const metadata = session.metadata || {};
  const userId = metadata.userId;
  if (!userId) {
    throw new Error(`HF Checkout Session ${session.id} is missing metadata.userId`);
  }

  validateUserPdfPair(metadata.techPdfUrl, metadata.photoPdfUrl, userId, "hf");

  if (metadata.basePriceCharged === "true" && metadata.reportKey) {
    await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("hfEstimateBasePayments")
      .doc(metadata.reportKey)
      .set(
        {
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          sessionId: session.id,
          claimNumber: metadata.claimNumber || "",
          address: metadata.address || "",
          dateInspected: metadata.dateInspected || "",
        },
        { merge: true }
      );
  }

  const isRush = metadata.rushOrder === "true";
  const deliveryText = isRush
    ? "will be delivered within next 6 hours."
    : "estimated delivery time 1-2 business days.";

  const body = [
    `We've received your Order and it's now being processed, ${deliveryText}`,
    "",
    "Order details:",
    `Client: ${metadata.clientName || "N/A"}`,
    `Claim #: ${metadata.claimNumber || "N/A"}`,
    `Address: ${metadata.address || "N/A"}`,
    `Date inspected: ${metadata.dateInspected || "N/A"}`,
    `Plan: ${metadata.plan || "N/A"}`,
    `Rush: ${isRush ? "Yes" : "No"}`,
    `Commercial: ${metadata.isCommercial === "true" ? "Yes" : "No"}`,
    `Shed: ${metadata.hasShed === "true" ? "Yes" : "No"}`,
    `Detached structure: ${metadata.hasDetachedStructure === "true" ? "Yes" : "No"}`,
    "",
    `Tech PDF: ${metadata.techPdfUrl}`,
    `Photo PDF: ${metadata.photoPdfUrl}`,
  ].join("\n");

  const userEmail = normalizeEmail(metadata.userEmail);
  const mailOptions = {
    from: '"ClaimScope Support" <soporte.claimscope@gmail.com>',
    to: "contact@hfestimates.com",
    cc: isValidEmail(userEmail) ? userEmail : undefined,
    subject: "New HF Estimates Order - Roof Inspection Report",
    text: body,
    attachments: [
      {
        filename: sanitizeAttachmentFilename(
          metadata.techFilename,
          "Inspection Tech Report.pdf"
        ),
        path: metadata.techPdfUrl,
      },
      {
        filename: sanitizeAttachmentFilename(
          metadata.photoFilename,
          "Inspection Photo Report.pdf"
        ),
        path: metadata.photoPdfUrl,
      },
    ],
  };

  const info = await transporter.sendMail(mailOptions);
  console.log("HF order email sent:", info.response);
}

function stripeResourceId(value) {
  if (typeof value === "string") return value;
  return value?.id || null;
}

function subscriptionIdFromInvoice(invoice) {
  return stripeResourceId(invoice?.subscription) ||
    stripeResourceId(invoice?.parent?.subscription_details?.subscription);
}

async function processStripeWebhookEvent(event, stripeClient, transporter) {
  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    if (session?.metadata?.kind === "hf_estimate_email") {
      await processHfCheckoutSession(session, transporter);
      return;
    }

    const subscriptionId = stripeResourceId(session.subscription);
    if (subscriptionId) {
      await refreshSubscriptionClaims(stripeClient, subscriptionId);
    }
    return;
  }

  if (event.type === "invoice.paid") {
    const invoice = event.data.object;
    const subscriptionId = subscriptionIdFromInvoice(invoice);
    if (subscriptionId) {
      await refreshSubscriptionClaims(stripeClient, subscriptionId);
    }
    return;
  }

  if (event.type === "customer.subscription.deleted") {
    await markSubscriptionDeleted(event.data.object);
  }
}

// 4. WEBHOOK STRIPE (V2)
exports.stripeWebhook = onRequest(
  { secrets: [stripeSecretKey, webhookSecret, emailPass] },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const sig = req.headers["stripe-signature"];
    let event;

    try {
      const stripeClient = Stripe(stripeSecretKey.value());
      event = stripeClient.webhooks.constructEvent(
        req.rawBody,
        sig,
        webhookSecret.value()
      );
    } catch (error) {
      console.error("Webhook signature failed:", error.message);
      return res.status(400).send(`Webhook Error: ${error.message}`);
    }

    let claim;
    try {
      claim = await claimStripeWebhookEvent(event);
    } catch (error) {
      console.error(`Could not claim Stripe event ${event.id}:`, error);
      return res.status(500).json({ received: false });
    }

    if (claim.state === "processed") {
      return res.json({ received: true, duplicate: true });
    }
    if (claim.state === "processing") {
      return res.status(409).json({ received: false, processing: true });
    }

    const stripeClient = Stripe(stripeSecretKey.value());
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: "soporte.claimscope@gmail.com",
        pass: emailPass.value(),
      },
    });

    try {
      await processStripeWebhookEvent(event, stripeClient, transporter);
      await markStripeWebhookProcessed(claim.ref);
      return res.json({ received: true });
    } catch (error) {
      console.error(`Error processing Stripe event ${event.id}:`, error);
      try {
        await markStripeWebhookFailed(claim.ref, error);
      } catch (markError) {
        console.error(`Could not mark Stripe event ${event.id} as failed:`, markError);
      }
      return res.status(500).json({ received: false });
    }
  }
);

// 5. DELETE ACCOUNT (V2)
exports.deleteAccount = onCall(
    {
        secrets: [stripeSecretKey],
        memory: "512MiB",
        timeoutSeconds: 120,
    },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "You must be signed in.");
        }

        const userId = request.auth.uid;
        const authTime = Number(request.auth.token.auth_time || 0);
        const currentTime = Math.floor(Date.now() / 1000);
        if (authTime <= 0 || currentTime - authTime > 5 * 60) {
            throw new HttpsError(
                "failed-precondition",
                "Please confirm your password again before deleting the account."
            );
        }

        const db = admin.firestore();
        const bucket = admin.storage().bucket();
        const stripeClient = Stripe(stripeSecretKey.value());

        let userRecord;
        try {
            userRecord = await admin.auth().getUser(userId);
        } catch (error) {
            if (error?.code === "auth/user-not-found") {
                throw new HttpsError("unauthenticated", "The user account no longer exists.");
            }
            console.error(`Could not load Firebase user ${userId}:`, error);
            throw new HttpsError("internal", "Account deletion could not be completed.");
        }

        try {
            await deleteStripeAccountData(stripeClient, userRecord.customClaims || {});

            await Promise.all([
                bucket.deleteFiles({ prefix: `user_reports/${userId}/` }),
                bucket.deleteFiles({ prefix: `temp_reports/${userId}/` }),
            ]);

            await db.recursiveDelete(db.collection("users").doc(userId));

            try {
                await admin.auth().deleteUser(userId);
            } catch (error) {
                if (error?.code !== "auth/user-not-found") throw error;
            }

            console.log(`Account and stored user data deleted: ${userId}`);
            return { success: true };
        } catch (error) {
            console.error(`Account deletion failed for ${userId}:`, error);
            throw new HttpsError(
                "internal",
                "Account deletion could not be completed. Please try again."
            );
        }
    }
);

// 6. CREATE CHECKOUT SESSION (V2)
exports.createCheckoutSession = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado");
    }

    let plan = normalizeSubscriptionPlan(request.data?.plan);
    let billingPeriod = normalizeBillingPeriod(request.data?.billingPeriod);

    if (!plan || !billingPeriod) {
      const legacySelection = resolveSubscriptionSelectionFromPriceId(
        request.data?.priceId
      );
      plan = legacySelection?.plan || null;
      billingPeriod = legacySelection?.billingPeriod || null;
    }

    if (!plan || !billingPeriod) {
      throw new HttpsError(
        "invalid-argument",
        "Plan and billing period must be valid."
      );
    }

    const priceId = resolveSubscriptionPriceId(plan, billingPeriod);
    const stripeClient = Stripe(stripeSecretKey.value());
    const subscriptionData = {
      metadata: {
        userId: request.auth.uid,
        plan,
        billingPeriod,
      },
    };

    if (plan === "premium") {
      subscriptionData.trial_period_days = 14;
    }

    const session = await stripeClient.checkout.sessions.create({
      mode: "subscription",
      payment_method_collection: "always",
      customer_email: request.auth.token.email || null,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: CHECKOUT_SUCCESS_URL,
      cancel_url: CHECKOUT_CANCEL_URL,
      subscription_data: subscriptionData,
    });

    return { url: session.url };
  }
);

exports.createHfEstimatesCheckoutSession = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado");
    }

    const {
      techPdfUrl,
      photoPdfUrl,
      rushOrder,
      clientName,
      claimNumber,
      address,
      dateInspected,
    } = request.data || {};
    const report = request.data?.report || {};

    if (!techPdfUrl || !photoPdfUrl) {
      throw new HttpsError("invalid-argument", "Faltan URLs de PDFs.");
    }

    const userId = request.auth.uid;
    const plan = requirePaidPlanFromAuth(request.auth);
    const isCommercial = report?.isCommercial === true;
    const isRushOrder = rushOrder === true;
    validateUserPdfPair(techPdfUrl, photoPdfUrl, userId, "hf");

    const stripeClient = Stripe(stripeSecretKey.value());
    const reportKey = buildHfReportKey(userId, claimNumber, address, dateInspected);
    const basePaymentRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("hfEstimateBasePayments")
      .doc(reportKey);

    const basePaymentSnap = await basePaymentRef.get();
    const baseAlreadyPaid = basePaymentSnap.exists;
    const chargeableElevations = hasChargeableElevationDetailsFromReport(report);

    const residentialRushFee = 15;
    const commercialRushFee = 25;
    const elevationsAddon = 55;

    let total = 0;
    let basePriceCharged = false;

    if (!baseAlreadyPaid) {
      const baseTotal = isCommercial
        ? calculateCommercialBasePrice(report)
        : calculateResidentialBasePrice(report);

      if (baseTotal === null) {
        throw new HttpsError(
          "failed-precondition",
          "This commercial report requires a custom HF Estimates order."
        );
      }

      total += baseTotal;
      basePriceCharged = true;
    }

    if (chargeableElevations) total += elevationsAddon;
    if (isRushOrder) {
      total += isCommercial ? commercialRushFee : residentialRushFee;
    }

    total = applyPlanDiscount(total, plan);

    if (total <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "No payable HF Estimates items were detected."
      );
    }

    const amountCents = Math.round(total * 100);
    const authenticatedEmail = normalizeEmail(request.auth.token.email);

    const session = await stripeClient.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      customer_email: isValidEmail(authenticatedEmail) ? authenticatedEmail : null,
      line_items: [
        {
          price_data: {
            currency: "usd",
            product_data: {
              name: "HF Estimates - Roof Estimate Order",
            },
            unit_amount: amountCents,
          },
          quantity: 1,
        },
      ],
      success_url: CHECKOUT_SUCCESS_URL,
      cancel_url: CHECKOUT_CANCEL_URL,
      metadata: {
        kind: "hf_estimate_email",
        userId,
        reportKey,
        basePriceCharged: basePriceCharged ? "true" : "false",
        baseAlreadyPaid: baseAlreadyPaid ? "true" : "false",
        chargeableElevations: chargeableElevations ? "true" : "false",
        techPdfUrl,
        photoPdfUrl,
        userEmail: isValidEmail(authenticatedEmail) ? authenticatedEmail : "",
        plan,
        rushOrder: isRushOrder ? "true" : "false",
        hasShed: report?.hasShed ? "true" : "false",
        hasDetachedStructure: report?.hasDetachedStructure ? "true" : "false",
        isCommercial: isCommercial ? "true" : "false",
        clientName: String(clientName || "").slice(0, 500),
        claimNumber: String(claimNumber || "").slice(0, 500),
        address: String(address || "").slice(0, 500),
        dateInspected: String(dateInspected || "").slice(0, 500),
      },
    });

    return { url: session.url };
  }
);

// ==========================================
// 7. SEND INSPECTION EMAIL (V2 - Consolidada)
// ==========================================
exports.sendInspectionEmail = onCall(
  {
    secrets: [emailPass],
    memory: "1GiB",
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debe iniciar sesión.");
    }

    const {
      extraEmail,
      toEmails,
      techPdfUrl,
      photoPdfUrl,
      techFilename,
      photoFilename,
    } = request.data || {};

    if (!techPdfUrl || !photoPdfUrl) {
      throw new HttpsError("invalid-argument", "Missing PDF URLs.");
    }

    const requestedExtraEmail = extraEmail || resolveLegacyExtraEmail(
      request.auth,
      toEmails
    );
    const cleanToEmails = resolveInspectionEmailRecipients(
      request.auth,
      requestedExtraEmail
    );
    validateUserPdfPair(
      techPdfUrl,
      photoPdfUrl,
      request.auth.uid,
      "email"
    );

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: "soporte.claimscope@gmail.com",
        pass: emailPass.value(),
      },
    });

    console.log(`Sending report links to: ${cleanToEmails.join(", ")}`);

    const safeTechFilename = sanitizeAttachmentFilename(
      techFilename,
      "Technical_Report.pdf"
    );
    const safePhotoFilename = sanitizeAttachmentFilename(
      photoFilename,
      "Photo_Report.pdf"
    );
    const emailText = [
      "Hello,",
      "",
      "Your requested inspection reports are ready. Due to the high-resolution images included, please use the links below to view and download your files securely:",
      "",
      `1. Technical Report (${safeTechFilename}):`,
      techPdfUrl,
      "",
      `2. Photo Report (${safePhotoFilename}):`,
      photoPdfUrl,
      "",
      "Thank you for using ClaimScope.",
      "Support Team",
    ].join("\n");

    const mailOptions = {
      from: '"ClaimScope Support" <soporte.claimscope@gmail.com>',
      to: cleanToEmails.join(","),
      subject: "Your Roof Inspection Report Links",
      text: emailText,
    };

    try {
      const info = await transporter.sendMail(mailOptions);
      console.log("Email with links sent successfully: " + info.response);
      return { success: true };
    } catch (error) {
      console.error("Detailed Email Error:", error);
      throw new HttpsError("internal", "Could not send email.");
    }
  }
);

exports.purgeExpiredInspectionReports = onSchedule(
  {
    schedule: "every day 02:00",
    timeZone: "America/Denver", // ajusta a tu zona si quieres
  },
  async () => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    const now = admin.firestore.Timestamp.now();

    // Busca en todas las subcolecciones "inspectionReports" de todos los usuarios
    const snap = await db.collectionGroup("inspectionReports")
      .where("expiresAt", "<=", now)
      .get();

    console.log(`purgeExpiredInspectionReports: found ${snap.size} expired reports`);

    for (const doc of snap.docs) {
      const data = doc.data();
      const techPath = data.techPath;
      const photoPath = data.photoPath;

      try {
        if (techPath) {
          await bucket.file(techPath).delete({ ignoreNotFound: true });
        }
        if (photoPath) {
          await bucket.file(photoPath).delete({ ignoreNotFound: true });
        }

        await doc.ref.delete();
        console.log(`Deleted report ${doc.ref.path}`);
      } catch (e) {
        console.error(`Error deleting report ${doc.ref.path}:`, e);
      }
    }

    return null;
  }
);