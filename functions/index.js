const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

const SHOPIFY_STORE = "makeup-mystery-india.myshopify.com";
const SHOPIFY_TOKEN = "dd608c57bca16ad54722334a67d5d521"; // 🔴 Replace this

exports.syncShopifyCustomer = functions.auth.user().onCreate(async (user) => {
  try {
    const email = user.email;

    // 1️⃣ Check if Shopify customer already exists
    const search = await axios.get(
        `https://${SHOPIFY_STORE}/admin/api/2025-01/customers/search.json?query=email:${email}`,
        {
          headers: {
            "X-Shopify-Access-Token": SHOPIFY_TOKEN,
          },
        },
    );

    let customer;

    if (search.data.customers.length > 0) {
      customer = search.data.customers[0];
      console.log("Customer exists in Shopify");
    } else {
      // 2️⃣ Create new Shopify customer
      const create = await axios.post(
          `https://${SHOPIFY_STORE}/admin/api/2025-01/customers.json`,
          {
            customer: {
              email: email,
              verified_email: true,
            },
          },
          {
            headers: {
              "X-Shopify-Access-Token": SHOPIFY_TOKEN,
            },
          },
      );

      customer = create.data.customer;
      console.log("Customer created in Shopify");
    }

    // 3️⃣ Save mapping in Firestore
    await admin.firestore().collection("users").doc(user.uid).set({
      email: email,
      shopifyCustomerId: customer.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Shopify sync error:", error.message);
  }
});
