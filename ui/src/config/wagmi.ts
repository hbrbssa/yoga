import { cookieStorage, createStorage, http } from "@wagmi/core";
import { WagmiAdapter } from "@reown/appkit-adapter-wagmi";
import { createAppKit } from "@reown/appkit";
import { mainnet, arbitrum, unichain } from "@reown/appkit/networks";

// Get environment variables
export const projectId =
  process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID || "";

if (!projectId) {
  throw new Error("Project ID is not defined");
}

export const networks = [mainnet, arbitrum, unichain];

export const wagmiAdapter = new WagmiAdapter({
  storage: createStorage({
    storage: cookieStorage,
    key: "wagmi.store",
  }),
  ssr: true,
  projectId,
  networks,
});

export const config = wagmiAdapter.wagmiConfig;
