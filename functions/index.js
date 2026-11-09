const { onCall, HttpsError } = require("firebase-functions/https");
const { setGlobalOptions } = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { defineSecret } = require("firebase-functions/params");
const Razorpay = require("razorpay");
const crypto = require("crypto");

initializeApp();

setGlobalOptions({
  maxInstances: 2,
});

const db = getFirestore();

const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

// ============================================================
// RAZORPAY ORDER
// ============================================================

function getServerSubscriptionPrice(flats, planType) {
  if (!Number.isInteger(flats) || flats <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "The society must have at least one flat."
    );
  }

  let monthlyPrice;
  let yearlyPrice;

  if (flats <= 30) {
    monthlyPrice = 499;
    yearlyPrice = 4999;
  } else if (flats <= 50) {
    monthlyPrice = 699;
    yearlyPrice = 6999;
  } else if (flats <= 100) {
    monthlyPrice = 999;
    yearlyPrice = 9999;
  } else if (flats <= 150) {
    monthlyPrice = 1499;
    yearlyPrice = 14999;
  } else if (flats <= 200) {
    monthlyPrice = 1999;
    yearlyPrice = 19999;
  } else {
    const extraTiers = Math.ceil((flats - 200) / 50);
    monthlyPrice = 1999 + extraTiers * 500;
    yearlyPrice = 19999 + extraTiers * 5000;
  }

  if (planType === "monthly") {
    return monthlyPrice;
  }

  if (planType === "yearly") {
    return yearlyPrice;
  }

  throw new HttpsError(
    "invalid-argument",
    "Choose monthly or yearly plan."
  );
}

exports.createRazorpayOrder = onCall(
  {
    secrets: [razorpayKeyId, razorpayKeySecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please sign in first."
      );
    }

    const societyId = String(
      request.data?.societyId ?? ""
    ).trim();

    const planType = String(
      request.data?.planType ?? ""
    ).trim().toLowerCase();

    if (!societyId) {
      throw new HttpsError(
        "invalid-argument",
        "Society ID is required."
      );
    }

    const societyRef = db
      .collection("societies")
      .doc(societyId);

    const societySnapshot = await societyRef.get();

    if (!societySnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Society not found."
      );
    }

    const society = societySnapshot.data();

    if (society.ownerId !== request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "Only the society owner can purchase a subscription."
      );
    }

    const flatsSnapshot = await societyRef
      .collection("flats")
      .count()
      .get();

    const flatCount = flatsSnapshot.data().count;

    const priceRupees = getServerSubscriptionPrice(
      flatCount,
      planType
    );

    const amountPaise = priceRupees * 100;

    try {
      const razorpay = new Razorpay({
        key_id: razorpayKeyId.value(),
        key_secret: razorpayKeySecret.value(),
      });

      const order = await razorpay.orders.create({
        amount: amountPaise,
        currency: "INR",
        receipt:`society_${Date.now()}`,
        notes: {
          societyId,
          planType,
          flatCount: String(flatCount),
          ownerUid: request.auth.uid,
        },
      });

      return {
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        keyId: razorpayKeyId.value(),
        planType,
        flatCount,
      };
    } catch (error) {
      console.error("Razorpay order creation failed:", error);

      throw new HttpsError(
        "internal",
        "Could not create payment order."
      );
    }
   }
 );

// ============================================================
// VERIFY RAZORPAY PAYMENT
// ============================================================

exports.verifyRazorpayPayment = onCall(
  {
    secrets: [razorpayKeyId, razorpayKeySecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please sign in first."
      );
    }

    const societyId = String(
      request.data?.societyId ?? ""
    ).trim();

    const orderId = String(
      request.data?.orderId ?? ""
    ).trim();

    const paymentId = String(
      request.data?.paymentId ?? ""
    ).trim();

    const signature = String(
      request.data?.signature ?? ""
    ).trim();

    if (!societyId || !orderId || !paymentId || !signature) {
      throw new HttpsError(
        "invalid-argument",
        "Payment verification details are required."
      );
    }

    const societyRef = db.collection("societies").doc(societyId);
    const societySnapshot = await societyRef.get();

    if (!societySnapshot.exists) {
      throw new HttpsError("not-found", "Society not found.");
    }

    if (societySnapshot.data().ownerId !== request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "Only the society owner can verify this payment."
      );
    }

    // Verify Razorpay signature on the server.
    const expectedSignature = crypto
      .createHmac("sha256", razorpayKeySecret.value())
      .update(`${orderId}|${paymentId}`)
      .digest("hex");

    if (!/^[a-fA-F0-9]{64}$/.test(signature)) {
      throw new HttpsError(
        "permission-denied",
        "Payment signature is invalid."
      );
    }

    const received = Buffer.from(signature, "hex");
    const expected = Buffer.from(expectedSignature, "hex");

    if (
      received.length !== expected.length ||
      !crypto.timingSafeEqual(received, expected)
    ) {
      throw new HttpsError(
        "permission-denied",
        "Payment signature is invalid."
      );
    }

    const paymentRef = db
      .collection("verified_payments")
      .doc(paymentId);

    // Prevent reuse of a payment already verified for another order.
    const existingPayment = await paymentRef.get();

    if (existingPayment.exists) {
      const saved = existingPayment.data();

      if (
        saved.ownerUid === request.auth.uid &&
        saved.societyId === societyId &&
        saved.orderId === orderId
      ) {
        return {
          success: true,
          message: "Payment was already verified.",
        };
      }

      throw new HttpsError(
        "already-exists",
        "This payment has already been used."
      );
    }

    const razorpay = new Razorpay({
      key_id: razorpayKeyId.value(),
      key_secret: razorpayKeySecret.value(),
    });

    let payment;
    let order;

    try {
      payment = await razorpay.payments.fetch(paymentId);
      order = await razorpay.orders.fetch(orderId);
    } catch (error) {
      console.error(
        "Razorpay payment/order fetch failed:",
        error.message
      );

      throw new HttpsError(
        "internal",
        "Could not verify payment with Razorpay."
      );
    }

    if (
      payment.order_id !== orderId ||
      payment.status !== "captured" ||
      payment.currency !== "INR"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Payment is not captured or does not match this order."
      );
    }

    if (
      order.status !== "paid" ||
      order.notes?.societyId !== societyId ||
      order.notes?.ownerUid !== request.auth.uid ||
      payment.amount !== order.amount ||
      payment.currency !== order.currency
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Payment details do not match the order."
      );
    }

    const planType = order.notes?.planType;

    if (planType !== "monthly" && planType !== "yearly") {
      throw new HttpsError(
        "failed-precondition",
        "Invalid subscription plan."
      );
    }

    // Use the flat count associated with the server-created order.
    const orderFlatCount = Number(order.notes?.flatCount);

    if (
      !Number.isInteger(orderFlatCount) ||
      orderFlatCount <= 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Invalid flat count in payment order."
      );
    }

    const expectedAmount =
      getServerSubscriptionPrice(orderFlatCount, planType) * 100;

    if (payment.amount !== expectedAmount) {
      throw new HttpsError(
        "failed-precondition",
        "Payment amount does not match the subscription price."
      );
    }

    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(paymentRef);
      const latestSociety = await transaction.get(societyRef);

      if (existing.exists) {
        const saved = existing.data();

        if (
          saved.ownerUid === request.auth.uid &&
          saved.societyId === societyId &&
          saved.orderId === orderId
        ) {
          return;
        }

        throw new HttpsError(
          "already-exists",
          "This payment has already been used."
        );
      }

      if (
        !latestSociety.exists ||
        latestSociety.data().ownerId !== request.auth.uid
      ) {
        throw new HttpsError(
          "permission-denied",
          "Society ownership could not be verified."
        );
      }

      const societyData = latestSociety.data();
      const now = new Date();

      const existingEnd =
        societyData.subscriptionEndAt?.toDate
          ? societyData.subscriptionEndAt.toDate()
          : null;

      const startDate =
        existingEnd && existingEnd > now
          ? existingEnd
          : now;

      const endDate = new Date(startDate);

      if (planType === "monthly") {
        endDate.setMonth(endDate.getMonth() + 1);
      } else {
        endDate.setFullYear(endDate.getFullYear() + 1);
      }

      transaction.create(paymentRef, {
        ownerUid: request.auth.uid,
        societyId,
        orderId,
        paymentId,
        amount: payment.amount,
        currency: payment.currency,
        planType,
        status: "captured",
        verifiedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(societyRef, {
        subscriptionStatus: "active",
        subscriptionPlan: planType,
        subscriptionStartAt: startDate,
        subscriptionEndAt: endDate,
        subscriptionFlatCount: orderFlatCount,
        subscriptionUpdatedAt: FieldValue.serverTimestamp(),
      });
    });

    // Log success only after the verification/transaction completes.
    console.log(
      "Razorpay payment verified and subscription activated.",
      { societyId, planType }
    );

    return {
      success: true,
      message: "Payment verified and subscription activated.",
    };
  }
);
// ============================================================
// RESIDENT INVITATION
// ============================================================

exports.redeemResidentInvitation = onCall(
  async (request) => {

    // User must be logged in
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please sign in first."
      );
    }

    const invitationCode = String(
      request.data?.invitationCode ?? ""
    )
      .trim()
      .toUpperCase();

    const email = String(
      request.data?.email ?? ""
    )
      .trim()
      .toLowerCase();

    // Validate invitation code
    if (!/^[A-Z0-9]{10}$/.test(invitationCode)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid invitation code."
      );
    }

    if (!email) {
      throw new HttpsError(
        "invalid-argument",
        "Email is required."
      );
    }

    const invitationRef = db
      .collection("resident_invitations")
      .doc(invitationCode);

    try {

      await db.runTransaction(async (transaction) => {

        // Get invitation
        const invitationSnapshot =
          await transaction.get(invitationRef);

        if (!invitationSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Invalid invitation code."
          );
        }

        const invitationData =
          invitationSnapshot.data();

        // Check if already used
        if (invitationData.used === true) {
          throw new HttpsError(
            "failed-precondition",
            "This invitation code has already been used."
          );
        }

        // Check email
        const invitationEmail =
          String(invitationData.email ?? "")
            .trim()
            .toLowerCase();

        if (invitationEmail !== email) {
          throw new HttpsError(
            "permission-denied",
            "This invitation belongs to a different email."
          );
        }

        const societyId =
          invitationData.societyId;

        const flatId =
          invitationData.flatId;

        const residentId =
          invitationData.residentId;

        if (!societyId || !flatId || !residentId) {
          throw new HttpsError(
            "failed-precondition",
            "Invitation data is incomplete."
          );
        }

        // Resident document
        const residentRef = db
          .collection("societies")
          .doc(societyId)
          .collection("flats")
          .doc(flatId)
          .collection("residents")
          .doc(residentId);

        const residentSnapshot =
          await transaction.get(residentRef);

        if (!residentSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Resident record not found."
          );
        }

        // Mark invitation as used
        transaction.update(invitationRef, {
          used: true,
          redeemedBy: request.auth.uid,
          redeemedAt: FieldValue.serverTimestamp(),
        });

        // Link Firebase account to resident
        transaction.update(residentRef, {
          userId: request.auth.uid,
          linkedAt: FieldValue.serverTimestamp(),
        });

        // Create resident role
        const userRoleRef = db
          .collection("user_roles")
          .doc(request.auth.uid);

        transaction.set(userRoleRef, {
          role: "resident",
          societyid: societyId,
          flatid: flatId,
          residentid: residentId,
          email: email,
          createdAt: FieldValue.serverTimestamp(),
        });
      });

      return {
        success: true,
        message: "Resident account linked successfully.",
      };

    } catch (error) {

      if (error instanceof HttpsError) {
        throw error;
      }

      console.error(
        "redeemResidentInvitation error:",
        error
      );

      throw new HttpsError(
        "internal",
        "Unable to verify invitation."
      );
    }
  }
);


// ============================================================
// GUARD INVITATION
// ============================================================

exports.redeemGuardInvitation = onCall(
  async (request) => {

    // User must be logged in
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please sign in first."
      );
    }

    const invitationCode = String(
      request.data?.invitationCode ?? ""
    )
      .trim()
      .toUpperCase();

    const email = String(
      request.data?.email ?? ""
    )
      .trim()
      .toLowerCase();

    // Validate invitation code
    if (!/^[A-Z0-9]{10}$/.test(invitationCode)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid invitation code."
      );
    }

    if (!email) {
      throw new HttpsError(
        "invalid-argument",
        "Email is required."
      );
    }

    const invitationRef = db
      .collection("guard_invitations")
      .doc(invitationCode);

    try {

      await db.runTransaction(async (transaction) => {

        // Get invitation
        const invitationSnapshot =
          await transaction.get(invitationRef);

        if (!invitationSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Invalid guard invitation code."
          );
        }

        const invitationData =
          invitationSnapshot.data();

        // Check if already used
        if (invitationData.used === true) {
          throw new HttpsError(
            "failed-precondition",
            "This guard invitation has already been used."
          );
        }

        // Check email
        const invitationEmail =
          String(invitationData.email ?? "")
            .trim()
            .toLowerCase();

        if (invitationEmail !== email) {
          throw new HttpsError(
            "permission-denied",
            "This invitation belongs to a different email."
          );
        }

        const societyId =
          invitationData.societyId;

        const guardId =
          invitationData.guardId;

        if (!societyId || !guardId) {
          throw new HttpsError(
            "failed-precondition",
            "Guard invitation data is incomplete."
          );
        }

        // Guard document
        const guardRef = db
          .collection("societies")
          .doc(societyId)
          .collection("guards")
          .doc(guardId);

        const guardSnapshot =
          await transaction.get(guardRef);

        if (!guardSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Guard record not found."
          );
        }

        // Mark invitation as used
        transaction.update(invitationRef, {
          used: true,
          redeemedBy: request.auth.uid,
          redeemedAt: FieldValue.serverTimestamp(),
        });

        // Link Firebase account to guard
        transaction.update(guardRef, {
          uid: request.auth.uid,
          linkedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // Create guard role
        const userRoleRef = db
          .collection("user_roles")
          .doc(request.auth.uid);

        transaction.set(userRoleRef, {
          role: "guard",
          societyid: societyId,
          guardid: guardId,
          email: email,
          createdAt: FieldValue.serverTimestamp(),
        });
      });

      return {
        success: true,
        message: "Guard account linked successfully.",
      };

    } catch (error) {

      if (error instanceof HttpsError) {
        throw error;
      }

      console.error(
        "redeemGuardInvitation error:",
        error
      );

      throw new HttpsError(
        "internal",
        "Unable to verify guard invitation."
      );
    }
  }
);

// ============================================================
// REGISTER NEW SOCIETY OWNER
// ============================================================

exports.registerOwner = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Please sign in first."
    );
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email || "";

  const userRoleRef = db.collection("user_roles").doc(uid);
  const existingRole = await userRoleRef.get();

  if (existingRole.exists) {
    if (existingRole.data().role === "owner") {
      return {
        success: true,
        message: "Owner already registered."
      };
    }

    throw new HttpsError(
      "already-exists",
      "This account already has another role."
    );
  }

  await userRoleRef.set({
    role: "owner",
    email: email,
    createdAt: FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    message: "Owner registration successful."
  };
});

// ============================================================
// GET MY ROLE
// ============================================================

exports.getMyRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Please sign in first."
    );
  }

  const uid = request.auth.uid;

  const roleSnapshot = await db
    .collection("user_roles")
    .doc(uid)
    .get();

  if (roleSnapshot.exists) {
    const role = roleSnapshot.data().role;

    if (["owner", "resident", "guard"].includes(role)) {
      return { role };
    }
  }

  const ownerSnapshot = await db
    .collection("societies")
    .where("ownerId", "==", uid)
    .limit(1)
    .get();

  if (!ownerSnapshot.empty) {
    return { role: "owner" };
  }

  return { role: "unknown" };
});

/* ============================================================
   VISITOR CHECK-IN NOTIFICATION
   ============================================================ */

exports.notifyResidentOnVisitorCheckIn = onDocumentCreated(
  "societies/{societyId}/visitors/{visitorId}",
  async (event) => {
    const visitor = event.data?.data();

    if (!visitor || visitor.status !== "Inside") {
      return;
    }

    const societyId = event.params.societyId;
    const flatId = visitor.flatId;

    if (!societyId || !flatId) {
      console.log("Missing societyId or flatId.");
      return;
    }

    try {
      // Find residents linked to this flat
      const residentsSnapshot = await db
        .collection("societies")
        .doc(societyId)
        .collection("flats")
        .doc(flatId)
        .collection("residents")
        .get();

      const tokens = [];

      for (const residentDoc of residentsSnapshot.docs) {
        const resident = residentDoc.data();
        const uid = resident.userId;

        if (!uid) continue;

        const tokenDoc = await db
          .collection("user_fcm_tokens")
          .doc(uid)
          .get();

        if (!tokenDoc.exists) continue;

        const token = tokenDoc.data()?.token;

        if (typeof token === "string" && token.length > 0) {
          tokens.push(token);
        }
      }

      // Remove duplicate device tokens
      const uniqueTokens = [...new Set(tokens)];

      if (uniqueTokens.length === 0) {
        console.log("No registered resident notification tokens.");
        return;
      }

      const visitorName =
        String(visitor.visitorName || "A visitor");

      const flatLabel =
        String(visitor.flatLabel || flatId);

      const result = await getMessaging().sendEachForMulticast({
        tokens: uniqueTokens,
        notification: {
          title: "Society Connect — Visitor Arrived",
          body: `${visitorName} has arrived for ${flatLabel}.`,
        },
        data: {
          type: "visitor_check_in",
          societyId: String(societyId),
          visitorId: String(event.params.visitorId),
          flatId: String(flatId),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "visitor_alerts",
          },
        },
      });

      console.log(
        `Visitor notifications: ${result.successCount} successful,
        ${result.failureCount} failed.`
      );
    } catch (error) {
      console.error("Visitor notification failed:", error);
      throw error;
    }
  }
);
