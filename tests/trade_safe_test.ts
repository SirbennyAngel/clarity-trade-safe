import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test create trade functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const buyer = accounts.get('wallet_1')!;
        const seller = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('trade-safe', 'create-trade', [
                types.principal(seller.address),
                types.uint(1000),
                types.uint(100),
                types.utf8("Test trade")
            ], buyer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
    }
});

Clarinet.test({
    name: "Test complete trade flow with ratings",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const buyer = accounts.get('wallet_1')!;
        const seller = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            // Create trade
            Tx.contractCall('trade-safe', 'create-trade', [
                types.principal(seller.address),
                types.uint(1000),
                types.uint(100),
                types.utf8("Test trade")
            ], buyer.address),
            
            // Confirm delivery
            Tx.contractCall('trade-safe', 'confirm-delivery', [
                types.uint(1)
            ], buyer.address),

            // Submit buyer rating
            Tx.contractCall('trade-safe', 'submit-rating', [
                types.uint(1),
                types.uint(1), // Positive rating
                types.utf8("Great seller!")
            ], buyer.address),

            // Submit seller rating
            Tx.contractCall('trade-safe', 'submit-rating', [
                types.uint(1),
                types.uint(1), // Positive rating
                types.utf8("Great buyer!")
            ], seller.address)
        ]);
        
        block.receipts.map(receipt => receipt.result.expectOk());
        
        // Verify ratings
        let ratingBlock = chain.mineBlock([
            Tx.contractCall('trade-safe', 'get-user-rating', [
                types.principal(seller.address)
            ], deployer.address)
        ]);
        
        const rating = ratingBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(rating['positive-ratings'], types.uint(1));
        assertEquals(rating['total-trades'], types.uint(1));
    }
});

Clarinet.test({
    name: "Test dispute functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const buyer = accounts.get('wallet_1')!;
        const seller = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            // Create trade
            Tx.contractCall('trade-safe', 'create-trade', [
                types.principal(seller.address),
                types.uint(1000),
                types.uint(100),
                types.utf8("Test trade")
            ], buyer.address),
            
            // Raise dispute
            Tx.contractCall('trade-safe', 'dispute-trade', [
                types.uint(1)
            ], seller.address)
        ]);
        
        block.receipts.map(receipt => receipt.result.expectOk());
        
        // Verify dispute status
        let statusBlock = chain.mineBlock([
            Tx.contractCall('trade-safe', 'get-trade', [
                types.uint(1)
            ], buyer.address)
        ]);
        
        const trade = statusBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(trade['status'], types.uint(2)); // DISPUTED
    }
});
