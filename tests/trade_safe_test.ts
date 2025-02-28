// [Previous imports and tests remain unchanged...]

Clarinet.test({
    name: "Test timeout functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const buyer = accounts.get('wallet_1')!;
        const seller = accounts.get('wallet_2')!;
        
        // Create trade with short timeout
        let block = chain.mineBlock([
            Tx.contractCall('trade-safe', 'create-trade', [
                types.principal(seller.address),
                types.uint(1000),
                types.uint(10), // Short timeout
                types.utf8("Test trade")
            ], buyer.address)
        ]);
        
        // Advance chain past timeout
        chain.mineEmptyBlockUntil(20);
        
        // Attempt confirmation after timeout
        let confirmBlock = chain.mineBlock([
            Tx.contractCall('trade-safe', 'confirm-delivery', [
                types.uint(1)
            ], buyer.address)
        ]);
        
        // Should fail with timeout error
        confirmBlock.receipts[0].result.expectErr(types.uint(107));
        
        // Recover expired trade
        let recoverBlock = chain.mineBlock([
            Tx.contractCall('trade-safe', 'recover-expired-trade', [
                types.uint(1)
            ], buyer.address)
        ]);
        
        recoverBlock.receipts[0].result.expectOk();
    }
});
