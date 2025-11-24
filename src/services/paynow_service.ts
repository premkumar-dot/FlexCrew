import functions from "@react-native-firebase/functions";

/**
 * createPayNowPayment(amount: number)
 * - Calls the Firebase callable function and returns server result
 */
export const createPayNowPayment = async (amount: number, returnUrl?: string) => {
  if (!amount || amount <= 0) throw new Error("Invalid amount");
  const fn = functions().httpsCallable("createPayNowPayment");
  const resp = await fn({ amount, returnUrl });
  return resp.data as { txId: string; paymentUrl?: string; qrImage?: string | null };
};