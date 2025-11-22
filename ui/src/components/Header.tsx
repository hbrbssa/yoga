"use client";

export function Header() {
  return (
    <header className="border-b">
      <div className="container mx-auto px-4 py-4">
        <div className="flex items-center justify-between">
          {/* Logo Section */}
          <div className="flex items-center gap-2">
            <div className="w-10 h-10 bg-gradient-to-br from-purple-500 to-blue-500 rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-xl">UP</span>
            </div>
            <div>
              <h1 className="text-xl font-bold">Uniswap Position Manager</h1>
              <p className="text-xs text-muted-foreground">
                Advanced Liquidity Control
              </p>
            </div>
          </div>

          {/* Wallet Connect Section */}
          <div className="flex items-center gap-4">
            <appkit-button />
          </div>
        </div>
      </div>
    </header>
  );
}
