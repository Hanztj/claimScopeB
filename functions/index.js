// 1. IMPORTS
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");
const Stripe = require("stripe");
const nodemailer = require("nodemailer");

// 2. INICIALIZACIÓN (Solo una vez)
admin.initializeApp();

// 3. CONFIGURACIÓN Y SECRETOS
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const webhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
const emailPass = defineSecret("EMAIL_PASS");

const priceBasic = defineString("STRIPE_PRICE_BASIC", {
    default: "price_1SXPDkIV8TkU9SxHb9qzNc4R"
});
const pricePremium = defineString("STRIPE_PRICE_PREMIUM", {
    default: "price_1SXPEDIV8TkU9SxHEMLdOOPO"
});

// Newer configuration for nodemailer using Gmail

function sanitizeAttachmentFilename(input, fallback) {
  const s = String(input || "").trim();
  if (!s) return fallback;
  return s.replace(/[\\/\:\*\?"<>\|]/g, "").trim() || fallback;
}
// 4. WEBHOOK STRIPE (V2)
exports.stripeWebhook = onRequest(
    { secrets: [stripeSecretKey, webhookSecret, emailPass] },
    async (req, res) => {
        if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

        const sig = req.headers["stripe-signature"];
        let event;

        try {
            const stripeClient = Stripe(stripeSecretKey.value());
            event = stripeClient.webhooks.constructEvent(req.rawBody, sig, webhookSecret.value());
        } catch (err) {
            console.error("Webhook signature failed:", err.message);
            return res.status(400).send(`Webhook Error: ${err.message}`);
        }

        const transporter = nodemailer.createTransport({
            service: "gmail",
            auth: {
                user: "soporte.claimscope@gmail.com",
                pass: emailPass.value(), // Usa el secreto de forma segura
            },
        });

        try {
            switch (event.type) {
                case "checkout.session.completed":
                case "invoice.paid": {
                    const session = event.data.object;

                        // HF Estimates one-time payment
  if (session?.metadata?.kind === "hf_estimate_email") {
    const techPdfUrl = session.metadata.techPdfUrl;
    const photoPdfUrl = session.metadata.photoPdfUrl;
    const userEmail = session.metadata.userEmail;

    const toEmail = 'contact@hfestimates.com'; // Email fijo para recibir notificaciones de pedidos

    const clientName = session.metadata.clientName || "N/A";
    const claimNumber = session.metadata.claimNumber || "N/A";
    const address = session.metadata.address || "N/A";
    const dateInspected = session.metadata.dateInspected || "N/A";
    const plan = session.metadata.plan || "N/A";
    const rushOrder = session.metadata.rushOrder === "true" ? "Yes" : "No";
    const isCommercial = session.metadata.isCommercial === "true" ? "Yes" : "No";
    const hasShed = session.metadata.hasShed === "true" ? "Yes" : "No";
    const hasDetachedStructure = session.metadata.hasDetachedStructure === "true" ? "Yes" : "No";

    const isRush = session.metadata.rushOrder === "true";
    const deliveryText = isRush
    ? "will be delivered within next 6 hours."
    : "estimated delivery time 1-2 business days.";

    const body = [
      `We've received your Order and it's now being processed, ${deliveryText}`,
      "",
      "Order details:",
      `Client: ${clientName}`,
      `Claim #: ${claimNumber}`,
      `Address: ${address}`,
      `Date inspected: ${dateInspected}`,
      `Plan: ${plan}`,
      `Rush: ${rushOrder}`,
      `Commercial: ${isCommercial}`,
      `Shed: ${hasShed}`,
      `Detached structure: ${hasDetachedStructure}`,
      "",
      `Tech PDF: ${techPdfUrl}`,
      `Photo PDF: ${photoPdfUrl}`,
    ].join("\n");

const mailOptions = {
  from: '"ClaimScope Support" <soporte.claimscope@gmail.com>',
  to: toEmail,
  cc: userEmail || undefined, // Enviar copia al cliente
  subject: "New HF Estimates Order - Roof Inspection Report",
  text: body,
attachments: [
  {
    filename: sanitizeAttachmentFilename(
      session.metadata.techFilename,
      "Inspection Tech Report.pdf"
    ),
    path: techPdfUrl,
  },
  {
    filename: sanitizeAttachmentFilename(
      session.metadata.photoFilename,
      "Inspection Photo Report.pdf"
    ),
    path: photoPdfUrl,
  },
],
};
      
    try {
      const info = await transporter.sendMail(mailOptions);
      console.log("HF order email sent:", info.response);
      break;
    } catch (error) {
      console.error("HF email error:", error);
      throw error;
    }
  }                      
                 //hf_estimate_Xactimate_API - one-time payment
if (session?.metadata?.kind === "hf_estimate_xactimate") {
  const techPdfUrl = session.metadata.techPdfUrl;
  const photoPdfUrl = session.metadata.photoPdfUrl;
  const userEmail = session.metadata.userEmail || session.customer_details?.email;

  const clientName = session.metadata.clientName || "N/A";
  const claimNumber = session.metadata.claimNumber || "N/A";
  const address = session.metadata.address || "N/A";
  const dateInspected = session.metadata.dateInspected || "N/A";
  const plan = session.metadata.plan || "N/A";
  const rushOrder = session.metadata.rushOrder === "true" ? "Yes" : "No";

  if (!userEmail) {
    console.error("hf_estimate_xactimate: missing userEmail");
    break;
  }
     const isRush = session.metadata.rushOrder === "true";
     const deliveryText = isRush
     ? "will be delivered within next 6 hours."
     : "estimated delivery time 1-2 business days.";
    const body = [
    `We've received your Order and it's now being processed, ${deliveryText}`,
    "",
    "NOTE: Xactimate assignment integration is POR IMPLEMENTAR (testing mode).",
    "Your payment was successful and your order has been recorded.",
    "",
    "Order details:",
    `Client: ${clientName}`,
    `Claim #: ${claimNumber}`,
    `Address: ${address}`,
    `Date inspected: ${dateInspected}`,
    `Plan: ${plan}`,
    `Rush: ${rushOrder}`,
    "",
    "Report links:",
    `Tech PDF: ${techPdfUrl}`,
    `Photo PDF: ${photoPdfUrl}`,
  ].join("\n");

  const mailOptions = {
    from: '"ClaimScope Support" <soporte.claimscope@gmail.com>',
    to: userEmail,
    cc: "contact@hfestimates.com",
    subject: "HF Estimates Order Received (Xactimate Assignment - POR IMPLEMENTAR)",
    text: body,
    attachments: [
      { filename: "Technical_Report.pdf", path: techPdfUrl },
      { filename: "Photo_Report.pdf", path: photoPdfUrl },
    ],
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log("hf_estimate_xactimate: confirmation sent:", info.response);
    break;
  } catch (error) {
    console.error("hf_estimate_xactimate email error:", error);
    throw error;
  }
}


                     // Solo para suscripciones, no para pagos one-time
                    const subscriptionId = session.subscription;
                    if (!subscriptionId) break;

                    const stripeClient = Stripe(stripeSecretKey.value());
                    const subscription = await stripeClient.subscriptions.retrieve(subscriptionId, { expand: ["items.data.price"] });

                    const priceId = subscription.items.data[0]?.price?.id;
                    const userId = subscription.metadata?.userId;

                    if (userId) {
                        const plan = priceId === pricePremium.value() ? "premium" : "basic";
                        await admin.auth().setCustomUserClaims(userId, {
                            plan,
                            stripeCustomerId: subscription.customer,
                            subscriptionId: subscription.id,
                        });
                        console.log(`Plan asignado: ${plan} a ${userId}`);
                    }
                    break;
                }
                case "customer.subscription.deleted": {
                    const subscription = event.data.object;
                    const userId = subscription.metadata?.userId;
                    if (userId) {
                        await admin.auth().setCustomUserClaims(userId, { plan: "basic", subscriptionId: null });
                    }
                    break;
                }
            }
        } catch (err) {
            console.error("Error procesando evento:", err);
        }
        res.json({ received: true });
    }
);

// 5. CREATE CHECKOUT SESSION (V2)
exports.createCheckoutSession = onCall(
    { secrets: [stripeSecretKey] },
    async (request) => {
        if (!request.auth) throw new HttpsError("unauthenticated", "Debes estar autenticado");

        const { priceId, successUrl, cancelUrl } = request.data;
        const stripeClient = Stripe(stripeSecretKey.value());

        const session = await stripeClient.checkout.sessions.create({
            mode: "subscription",
            payment_method_collection: "always",
            customer_email: request.auth.token.email || null,
            line_items: [{ price: priceId, quantity: 1 }],
            success_url: successUrl || "claimscope://success",
            cancel_url: cancelUrl || "claimscope://cancel",
            subscription_data: { metadata: { userId: request.auth.uid } },
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
      hasShed,
      hasDetachedStructure,
      isCommercial,
      plan, // 'basic' o 'premium'
      clientName,
      claimNumber,
      address,
      dateInspected,
      userEmail,
      successUrl,
      cancelUrl,
    } = request.data;

    if (!techPdfUrl || !photoPdfUrl) {
      throw new HttpsError("invalid-argument", "Faltan URLs de PDFs.");
    }

    const stripeClient = Stripe(stripeSecretKey.value());

    // ----- Pricing (USD) -----
    const basePrice = 70;
    const shedAddon = 10;
    const structureAddon = 15;
    const rushFee = 15;
    const commercialExtra = 20;

    let total = basePrice;
    if (hasShed) total += shedAddon;
    if (hasDetachedStructure) total += structureAddon;
    if (isCommercial) total += commercialExtra;
    if (rushOrder) total += rushFee;

    // Discounts: basic 10%, premium 15%
    if (plan === "basic") total *= 0.90;
    if (plan === "premium") total *= 0.85;

    // Stripe requiere centavos como entero
    const amountCents = Math.round(total * 100);

    const session = await stripeClient.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      customer_email: userEmail || request.auth.token.email || null,

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

      success_url: successUrl || "claimscope://success",
      cancel_url: cancelUrl || "claimscope://cancel",

      metadata: {
        kind: "hf_estimate_email",
        techPdfUrl,
        photoPdfUrl,
        userEmail: userEmail || request.auth.token.email || "",
        plan: plan || "",
        rushOrder: rushOrder ? "true" : "false",
        hasShed: hasShed ? "true" : "false",
        hasDetachedStructure: hasDetachedStructure ? "true" : "false",
        isCommercial: isCommercial ? "true" : "false",
        clientName: clientName || "",
        claimNumber: claimNumber || "",
        address: address || "",
        dateInspected: dateInspected || "",
      },
    });

    return { url: session.url };
  }
);
//5.2 Create Xactimate API Checkout Session (Placeholder)
exports.createHfEstimatesXactimateCheckoutSession = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado");
    }
    const {
      techPdfUrl,
      photoPdfUrl,
      rushOrder,
      hasShed,
      hasDetachedStructure,
      isCommercial,
      plan,
      clientName,
      claimNumber,
      address,
      dateInspected,
      userEmail,
      successUrl,
      cancelUrl,
    } = request.data;

    if (!techPdfUrl || !photoPdfUrl) {
      throw new HttpsError("invalid-argument", "Faltan URLs de PDFs.");
    }

    const stripeClient = Stripe(stripeSecretKey.value());

    const basePrice = 70;
    const shedAddon = 10;
    const structureAddon = 15;
    const rushFee = 15;
    const commercialExtra = 20;

    let total = basePrice;
    if (hasShed) total += shedAddon;
    if (hasDetachedStructure) total += structureAddon;
    if (isCommercial) total += commercialExtra;
    if (rushOrder) total += rushFee;

    if (plan === "basic") total *= 0.90;
    if (plan === "premium") total *= 0.85;

    const amountCents = Math.round(total * 100);

    const session = await stripeClient.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      customer_email: userEmail || request.auth.token.email || null,

      line_items: [
        {
          price_data: {
            currency: "usd",
            product_data: {
              name: "HF Estimates - Xactimate Assignment Order",
            },
            unit_amount: amountCents,
          },
          quantity: 1,
        },
      ],

      success_url: successUrl || "claimscope://success",
      cancel_url: cancelUrl || "claimscope://cancel",

      metadata: {
        kind: "hf_estimate_xactimate",
        techPdfUrl,
        photoPdfUrl,
        userEmail: userEmail || request.auth.token.email || "",
        plan: plan || "",
        rushOrder: rushOrder ? "true" : "false",
        hasShed: hasShed ? "true" : "false",
        hasDetachedStructure: hasDetachedStructure ? "true" : "false",
        isCommercial: isCommercial ? "true" : "false",
        clientName: clientName || "",
        claimNumber: claimNumber || "",
        address: address || "",
        dateInspected: dateInspected || "",
      },
    });

    return { url: session.url };
  }
);
// 6. SEND INSPECTION EMAIL (V2 - Consolidada)
// Esta versión usa las URLs de los archivos para no saturar la memoria
exports.sendInspectionEmail = onCall(
    { secrets: [emailPass] }, // <-- 1er argumento: Objeto de configuración
    async (request) => {      // <-- 2do argumento: Tu función async de siempre
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "Debe iniciar sesión.");
        }

        const transporter = nodemailer.createTransport({
            service: "gmail",
            auth: {
                user: "soporte.claimscope@gmail.com",
                pass: emailPass.value(),
            },
        });

    const { toEmails, techPdfUrl, photoPdfUrl, techFilename, photoFilename } = request.data;
    if (!techPdfUrl || !photoPdfUrl) {
  throw new HttpsError("invalid-argument", "Missing PDF URLs.");
}

    const cleanToEmails = Array.isArray(toEmails)
  ? toEmails.map((e) => String(e || "").trim()).filter((e) => e.length > 0)
  : [];

if (cleanToEmails.length === 0) {
  console.error("sendInspectionEmail: no recipients", { toEmails });
  throw new HttpsError("invalid-argument", "No recipients provided.");
}

console.log(`Sending report to: ${cleanToEmails.join(", ")}`);

const mailOptions = { 
  from: '"ClaimScope Support" <soporte.claimscope@gmail.com>',
  to: cleanToEmails.join(","),
  subject: "Your Roof Inspection Report 🚀",
  text: "Attached are your requested inspection reports.",
  attachments: [
    { filename: techFilename, path: techPdfUrl }, 
    { filename: photoFilename, path: photoPdfUrl }
  ]
};
    try {
        const info = await transporter.sendMail(mailOptions);
        console.log("Email sent successfully: " + info.response);
        return { success: true };
    } catch (error) {
        console.error("Detailed Email Error:", error);
        throw new HttpsError("internal", "Could not send email.");
    }
});
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