/**
 * @description Test class for AccountRatingCalculator
 * @author ACME Corporation
 * @date 2026-03-19
 */
@isTest
private class AccountRatingCalculatorTest_copado {

    /**
     * @description Test data setup - creates accounts and opportunities for all test scenarios
     */
    @testSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();

        // Hot Account - High revenue, high employees, many opportunities
        Account hotAccount = new Account(
            Name = 'Hot Test Account',
            AnnualRevenue = 15000000,
            NumberOfEmployees = 1500
        );
        accounts.add(hotAccount);

        // Warm Account - Medium revenue, medium employees, some opportunities
        Account warmAccount = new Account(
            Name = 'Warm Test Account',
            AnnualRevenue = 6000000,
            NumberOfEmployees = 600
        );
        accounts.add(warmAccount);

        // Cold Account - Low revenue, low employees, few opportunities
        Account coldAccount = new Account(
            Name = 'Cold Test Account',
            AnnualRevenue = 500000,
            NumberOfEmployees = 50
        );
        accounts.add(coldAccount);

        // Zero values account
        Account zeroAccount = new Account(
            Name = 'Zero Test Account',
            AnnualRevenue = 0,
            NumberOfEmployees = 0
        );
        accounts.add(zeroAccount);

        // Null values account
        Account nullAccount = new Account(
            Name = 'Null Test Account'
        );
        accounts.add(nullAccount);

        insert accounts;

        // Create 12 opportunities for hot account (tier 1 = 3 points)
        List<Opportunity> allOpps = new List<Opportunity>();
        for (Integer i = 0; i < 12; i++) {
            allOpps.add(new Opportunity(
                Name = 'Hot Opp ' + i,
                AccountId = hotAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }

        // Create 6 opportunities for warm account (tier 2 = 2 points)
        for (Integer i = 0; i < 6; i++) {
            allOpps.add(new Opportunity(
                Name = 'Warm Opp ' + i,
                AccountId = warmAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }

        // Create 1 opportunity for cold account (tier 3 = 1 point)
        allOpps.add(new Opportunity(
            Name = 'Cold Opp',
            AccountId = coldAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        ));

        insert allOpps;
    }

    /**
     * @description Test hot rating calculation
     */
    @isTest
    static void testHotRatingCalculation() {
        Account hotAccount = [SELECT Id FROM Account WHERE Name = 'Hot Test Account' LIMIT 1];
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator_copado.calculateAccountRating(hotAccount.Id);
            System.assertEquals('Hot', rating, 'Account should be rated as Hot');
        }
        Test.stopTest();
    }

    /**
     * @description Test warm rating calculation
     */
    @isTest
    static void testWarmRatingCalculation() {
        Account warmAccount = [SELECT Id FROM Account WHERE Name = 'Warm Test Account' LIMIT 1];
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator_copado.calculateAccountRating(warmAccount.Id);
            System.assertEquals('Warm', rating, 'Account should be rated as Warm');
        }
        Test.stopTest();
    }

    /**
     * @description Test cold rating calculation
     */
    @isTest
    static void testColdRatingCalculation() {
        Account coldAccount = [SELECT Id FROM Account WHERE Name = 'Cold Test Account' LIMIT 1];
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator_copado.calculateAccountRating(coldAccount.Id);
            System.assertEquals('Cold', rating, 'Account should be rated as Cold');
        }
        Test.stopTest();
    }

    /**
     * @description Test zero values account defaults to Cold
     */
    @isTest
    static void testZeroValuesAccount() {
        Account zeroAccount = [SELECT Id FROM Account WHERE Name = 'Zero Test Account' LIMIT 1];
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator_copado.calculateAccountRating(zeroAccount.Id);
            System.assertEquals('Cold', rating, 'Account with zero values should be rated as Cold');
        }
        Test.stopTest();
    }

    /**
     * @description Test null values account defaults to Cold
     */
    @isTest
    static void testNullValuesAccount() {
        Account nullAccount = [SELECT Id FROM Account WHERE Name = 'Null Test Account' LIMIT 1];
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator_copado.calculateAccountRating(nullAccount.Id);
            System.assertEquals('Cold', rating, 'Account with null values should be rated as Cold');
        }
        Test.stopTest();
    }

    /**
     * @description Test bulk rating calculation across all accounts
     */
    @isTest
    static void testBulkRatingCalculation() {
        List<Account> accounts = [SELECT Id, Name FROM Account];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Map<Id, String> ratings = AccountRatingCalculator_copado.calculateAccountRatings(accountIds);
            System.assertEquals(5, ratings.size(), 'Should calculate ratings for all 5 accounts');
            System.assert(ratings.values().contains('Hot'), 'Should have at least one Hot rating');
            System.assert(ratings.values().contains('Warm'), 'Should have at least one Warm rating');
            System.assert(ratings.values().contains('Cold'), 'Should have at least one Cold rating');
        }
        Test.stopTest();
    }

    /**
     * @description Test update account ratings persists to database
     */
    @isTest
    static void testUpdateAccountRatings() {
        List<Account> accounts = [SELECT Id FROM Account];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            AccountRatingCalculator_copado.updateAccountRatings(accountIds);
        }
        Test.stopTest();
        List<Account> updatedAccounts = [SELECT Id, Name, Rating FROM Account];
        for (Account acc : updatedAccounts) {
            System.assertNotEquals(null, acc.Rating, 'Rating should be updated for account: ' + acc.Name);
        }
    }

    /**
     * @description Test null account ID throws AccountRatingException
     */
    @isTest
    static void testNullAccountIdException() {
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            try {
                AccountRatingCalculator_copado.calculateAccountRating(null);
                System.assert(false, 'Should throw exception for null account ID');
            } catch (AccountRatingCalculator_copado.AccountRatingException e) {
                System.assert(e.getMessage().contains('cannot be null'), 'Exception message should mention null ID');
            }
        }
        Test.stopTest();
    }

    /**
     * @description Test invalid account ID throws AccountRatingException
     */
    @isTest
    static void testInvalidAccountIdException() {
        String keyPrefix = Account.SObjectType.getDescribe().getKeyPrefix();
        Id fakeId = Id.valueOf(keyPrefix + '0'.repeat(15 - keyPrefix.length()));
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            try {
                AccountRatingCalculator_copado.calculateAccountRating(fakeId);
                System.assert(false, 'Should throw exception for invalid account ID');
            } catch (AccountRatingCalculator_copado.AccountRatingException e) {
                System.assert(e.getMessage().contains('not found'), 'Exception message should mention account not found');
            }
        }
        Test.stopTest();
    }

    /**
     * @description Test empty set returns empty map
     */
    @isTest
    static void testEmptySetHandling() {
        Set<Id> emptySet = new Set<Id>();
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Map<Id, String> ratings = AccountRatingCalculator_copado.calculateAccountRatings(emptySet);
            System.assertEquals(0, ratings.size(), 'Should return empty map for empty set');
        }
        Test.stopTest();
    }

    /**
     * @description Test null set returns empty map
     */
    @isTest
    static void testNullSetHandling() {
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Map<Id, String> ratings = AccountRatingCalculator_copado.calculateAccountRatings(null);
            System.assertEquals(0, ratings.size(), 'Should return empty map for null set');
        }
        Test.stopTest();
    }

    /**
     * @description Test revenue scoring tiers produce non-null ratings
     */
    @isTest
    static void testRevenueScoringTiers() {
        List<Account> testAccounts = new List<Account>{
            new Account(Name = 'Revenue Tier 1', AnnualRevenue = 10000000, NumberOfEmployees = 0),
            new Account(Name = 'Revenue Tier 2', AnnualRevenue = 5000000,  NumberOfEmployees = 0),
            new Account(Name = 'Revenue Tier 3', AnnualRevenue = 1000000,  NumberOfEmployees = 0)
        };
        insert testAccounts;
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            for (Account acc : testAccounts) {
                String rating = AccountRatingCalculator_copado.calculateAccountRating(acc.Id);
                System.assertNotEquals(null, rating, 'Rating should be calculated for ' + acc.Name);
            }
        }
        Test.stopTest();
    }

    /**
     * @description Test employee scoring tiers produce non-null ratings
     */
    @isTest
    static void testEmployeeScoringTiers() {
        List<Account> testAccounts = new List<Account>{
            new Account(Name = 'Employee Tier 1', NumberOfEmployees = 1000, AnnualRevenue = 0),
            new Account(Name = 'Employee Tier 2', NumberOfEmployees = 500,  AnnualRevenue = 0),
            new Account(Name = 'Employee Tier 3', NumberOfEmployees = 100,  AnnualRevenue = 0)
        };
        insert testAccounts;
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            for (Account acc : testAccounts) {
                String rating = AccountRatingCalculator_copado.calculateAccountRating(acc.Id);
                System.assertNotEquals(null, rating, 'Rating should be calculated for ' + acc.Name);
            }
        }
        Test.stopTest();
    }

    /**
     * @description Test opportunity scoring tiers produce non-null ratings
     */
    @isTest
    static void testOpportunityScoringTiers() {
        Account testAccount = new Account(
            Name = 'Opportunity Tier Test',
            AnnualRevenue = 0,
            NumberOfEmployees = 0
        );
        insert testAccount;
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 10; i++) {
            opps.add(new Opportunity(
                Name = 'Test Opp ' + i,
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator_copado.calculateAccountRating(testAccount.Id);
            System.assertNotEquals(null, rating, 'Rating should be calculated for opportunity tier test account');
        }
        Test.stopTest();
    }

    /**
     * @description Test Flow invocable method with valid account IDs
     */
    @isTest
    static void testUpdateAccountRatingFromFlow() {
        Account hotAccount = [SELECT Id FROM Account WHERE Name = 'Hot Test Account' LIMIT 1];
        AccountRatingCalculator_copado.FlowRequest req = new AccountRatingCalculator_copado.FlowRequest();
        req.accountId = hotAccount.Id;
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            AccountRatingCalculator_copado.updateAccountRatingFromFlow(
                new List<AccountRatingCalculator_copado.FlowRequest>{ req }
            );
        }
        Test.stopTest();
        Account updated = [SELECT Rating FROM Account WHERE Id = :hotAccount.Id];
        System.assertEquals('Hot', updated.Rating, 'Flow invocable should set Hot rating');
    }

    /**
     * @description Test Flow invocable method with null request list
     */
    @isTest
    static void testUpdateAccountRatingFromFlowNullList() {
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            AccountRatingCalculator_copado.updateAccountRatingFromFlow(null);
            System.assert(true, 'Null request list should be handled gracefully');
        }
        Test.stopTest();
    }
}