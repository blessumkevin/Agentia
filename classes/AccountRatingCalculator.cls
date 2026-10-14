/**
 * @description Calculates and assigns a Hot/Warm/Cold rating to Account records
 *              using a point-based scoring system derived from Annual Revenue,
 *              Number of Employees, and related Opportunities.
 *
 *              Scoring thresholds:
 *                7+ points => Hot
 *                4+ points => Warm
 *                Below 4   => Cold
 *
 * @author      Copado Build Agent
 * @date        2026-10-14
 */
public with sharing class AccountRatingCalculator {

    // ─── Scoring Thresholds ───────────────────────────────────────────────────
    private static final Integer HOT_THRESHOLD  = 7;
    private static final Integer WARM_THRESHOLD = 4;

    // ─── Rating Values ────────────────────────────────────────────────────────
    private static final String RATING_HOT  = 'Hot';
    private static final String RATING_WARM = 'Warm';
    private static final String RATING_COLD = 'Cold';

    // ─── Revenue Scoring Bands ────────────────────────────────────────────────
    private static final Decimal REVENUE_HIGH   = 10000000;
    private static final Decimal REVENUE_MEDIUM = 1000000;

    // ─── Employee Scoring Bands ───────────────────────────────────────────────
    private static final Integer EMPLOYEES_HIGH   = 1000;
    private static final Integer EMPLOYEES_MEDIUM = 100;

    // ─── Opportunity Scoring Bands ────────────────────────────────────────────
    private static final Integer OPP_HIGH   = 5;
    private static final Integer OPP_MEDIUM = 2;

    /**
     * @description Invocable entry point called by the auto-launched Flow.
     *              Accepts a list of Account Ids, queries the full Account records,
     *              calculates their ratings, and persists the result via DML.
     *
     * @param       accountIds  List of Account Ids passed from the Flow trigger.
     */
    @InvocableMethod(
        label       = 'Calculate Account Rating'
        description = 'Calculates and assigns Hot/Warm/Cold rating to Account records based on revenue, employees, and opportunities.'
        category    = 'Account'
    )
    public static void calculateRatingsInvocable(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        List<Account> accounts = [
            SELECT Id, AnnualRevenue, NumberOfEmployees
            FROM   Account
            WHERE  Id IN :accountIds
            WITH   SECURITY_ENFORCED
        ];

        calculateRatings(accounts);

        update accounts; // NOPMD
    }

    /**
     * @description Calculates ratings for a list of Accounts and updates the
     *              Rating field in-memory. Performs a single bulkified SOQL
     *              query to retrieve related Opportunity counts.
     *
     * @param       accounts  List of Account records to evaluate.
     */
    public static void calculateRatings(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }

        // Collect Account Ids for the bulk Opportunity query
        Set<Id> accountIdSet = new Set<Id>();
        for (Account acc : accounts) {
            if (acc.Id != null) {
                accountIdSet.add(acc.Id);
            }
        }

        // Bulkified SOQL: one query for all Opportunity counts
        Map<Id, Integer> oppCountByAccountId = getOpportunityCountMap(accountIdSet);

        // Evaluate and assign rating for each Account
        for (Account acc : accounts) {
            Integer score = scoreAccount(acc, oppCountByAccountId.get(acc.Id));
            acc.Rating = deriveRating(score);
        }
    }

    /**
     * @description Queries Opportunity counts grouped by AccountId for the
     *              provided set of Account Ids.
     *
     * @param       accountIds  Set of Account Ids to query against.
     * @return      Map of AccountId to Opportunity count.
     */
    @TestVisible
    private static Map<Id, Integer> getOpportunityCountMap(Set<Id> accountIds) {
        Map<Id, Integer> oppCountMap = new Map<Id, Integer>();

        if (accountIds == null || accountIds.isEmpty()) {
            return oppCountMap;
        }

        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) oppCount
            FROM   Opportunity
            WHERE  AccountId IN :accountIds
            GROUP BY AccountId
        ]) {
            oppCountMap.put(
                (Id)      ar.get('AccountId'),
                (Integer) ar.get('oppCount')
            );
        }

        return oppCountMap;
    }

    /**
     * @description Computes the total score for a single Account based on
     *              Annual Revenue, Number of Employees, and Opportunity count.
     *
     * @param       acc       The Account record to score.
     * @param       oppCount  Number of related Opportunities (may be null).
     * @return      Integer score.
     */
    @TestVisible
    private static Integer scoreAccount(Account acc, Integer oppCount) {
        Integer score = 0;
        score += scoreRevenue(acc.AnnualRevenue);
        score += scoreEmployees(acc.NumberOfEmployees);
        score += scoreOpportunities(oppCount);
        return score;
    }

    /**
     * @description Assigns revenue points based on Annual Revenue bands.
     *
     * @param       annualRevenue  The account's Annual Revenue value.
     * @return      Points awarded: 3 (high), 2 (medium), or 1 (low/null).
     */
    @TestVisible
    private static Integer scoreRevenue(Decimal annualRevenue) {
        if (annualRevenue == null) {
            return 1;
        }
        if (annualRevenue >= REVENUE_HIGH) {
            return 3;
        }
        if (annualRevenue >= REVENUE_MEDIUM) {
            return 2;
        }
        return 1;
    }

    /**
     * @description Assigns employee points based on Number of Employees bands.
     *
     * @param       numberOfEmployees  The account's Number of Employees value.
     * @return      Points awarded: 3 (high), 2 (medium), or 1 (low/null).
     */
    @TestVisible
    private static Integer scoreEmployees(Integer numberOfEmployees) {
        if (numberOfEmployees == null) {
            return 1;
        }
        if (numberOfEmployees >= EMPLOYEES_HIGH) {
            return 3;
        }
        if (numberOfEmployees >= EMPLOYEES_MEDIUM) {
            return 2;
        }
        return 1;
    }

    /**
     * @description Assigns opportunity points based on related Opportunity count.
     *
     * @param       oppCount  Number of related Opportunities (may be null).
     * @return      Points awarded: 3 (high), 2 (medium), or 1 (low/null).
     */
    @TestVisible
    private static Integer scoreOpportunities(Integer oppCount) {
        if (oppCount == null || oppCount == 0) {
            return 1;
        }
        if (oppCount >= OPP_HIGH) {
            return 3;
        }
        if (oppCount >= OPP_MEDIUM) {
            return 2;
        }
        return 1;
    }

    /**
     * @description Converts a numeric score into a Rating string value.
     *
     * @param       score  The computed score for an Account.
     * @return      'Hot', 'Warm', or 'Cold'.
     */
    @TestVisible
    private static String deriveRating(Integer score) {
        if (score >= HOT_THRESHOLD) {
            return RATING_HOT;
        }
        if (score >= WARM_THRESHOLD) {
            return RATING_WARM;
        }
        return RATING_COLD;
    }
}