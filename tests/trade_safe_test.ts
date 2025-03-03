Clarinet.test({
    name: "Test timeout functionality and recovery",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const buyer = accounts.get('wallet_1')!;
        const seller = accounts.get('wallet_2')!;
        
        // Create trade with short timeout
        let block = chain.mineBlock([
            Tx.contractCall('trade-safe', 'create-trade', [
                types.principal(seller.address),
                types.uint(1000),
                types.uint(15), // Timeout > MIN-TIMEOUT
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

        // Attempt second recovery (should fail)
        let secondRecoverBlock = chain.mineBlock([
            Tx.contractCall('trade-safe', 'recover-expired-trade', [
                types.uint(1)
            ], buyer.address)
        ]);
        
        secondRecoverBlock.receipts[0].result.expectErr(types.uint(105));
    }
});
