/**
 * @description Calculates and assigns a Hot/Warm/Cold rating to Account records
 *              using a point-based scoring system derived from AnnualRevenue,
 *              NumberOfEmployees, and related Opportunities.
 *
 *              Scoring thresholds:
 *                - 7+ points => Hot
 *                - 4+ points => Warm
 *                - <4 points => Cold
 *
 * @author      Copado Build Agent
 * @date        2026-09-22
 */
public with sharing class AccountRatingCalculator {

    // ─── Scoring Thresholds ───────────────────────────────────────────────────
    @TestVisible private static final Integer HOT_THRESHOLD  = 7;
    @TestVisible private static final Integer WARM_THRESHOLD = 4;

    // ─── Rating Values ────────────────────────────────────────────────────────
    @TestVisible private static final String RATING_HOT  = 'Hot';
    @TestVisible private static final String RATING_WARM = 'Warm';
    @TestVisible private static final String RATING_COLD = 'Cold';

    // ─── Revenue Bands (Annual Revenue points) ────────────────────────────────
    @TestVisible private static final Decimal REVENUE_HIGH   = 10000000;  // 3 pts
    @TestVisible private static final Decimal REVENUE_MEDIUM = 1000000;   // 2 pts
    @TestVisible private static final Decimal REVENUE_LOW    = 100000;    // 1 pt

    // ─── Employee Bands ───────────────────────────────────────────────────────
    @TestVisible private static final Integer EMP_HIGH   = 1000;  // 3 pts
    @TestVisible private static final Integer EMP_MEDIUM = 200;   // 2 pts
    @TestVisible private static final Integer EMP_LOW    = 50;    // 1 pt

    // ─── Opportunity Points ───────────────────────────────────────────────────
    @TestVisible private static final Integer OPP_POINTS = 1;  // per open Opportunity (max 1 applied)

    /**
     * @description Entry point invoked by the auto-launched Flow.
     *              Accepts a list of Account IDs, calculates ratings, and
     *              performs a single DML update.
     *
     * @param accountIds  List of Account IDs to process.
     */
    @InvocableMethod(label='Calculate Account Rating'
                     description='Calculates and updates the Rating field on the provided Accounts.')
    public static void calculateRatings(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        // Deduplicate IDs to avoid redundant processing
        Set<Id> uniqueIds = new Set<Id>(accountIds);

        // Single SOQL: fetch accounts + sub-query open Opps in one query
        List<Account> accounts = [
            SELECT Id, Rating, AnnualRevenue, NumberOfEmployees,
                   (SELECT Id FROM Opportunities WHERE IsClosed = FALSE LIMIT 1)
            FROM   Account
            WHERE  Id IN :uniqueIds
            WITH   SECURITY_ENFORCED
        ];

        List<Account> toUpdate = new List<Account>();

        for (Account acc : accounts) {
            Integer score      = computeScore(acc);
            String  newRating  = deriveRating(score);

            // Only update if the rating actually changes
            if (acc.Rating != newRating) {
                toUpdate.add(new Account(Id = acc.Id, Rating = newRating));
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate; // bulkified single DML
        }
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    /**
     * @description Computes the total score for a single Account.
     *
     * @param  acc  The Account record (must include AnnualRevenue,
     *              NumberOfEmployees, and Opportunities sub-query).
     * @return      Integer score.
     */
    @TestVisible
    private static Integer computeScore(Account acc) {
        Integer score = 0;
        score += revenuePoints(acc.AnnualRevenue);
        score += employeePoints(acc.NumberOfEmployees);
        score += opportunityPoints(acc.Opportunities);
        return score;
    }

    /**
     * @description Returns revenue-based points.
     *
     * @param  revenue  AnnualRevenue value (may be null).
     * @return          0-3 points.
     */
    @TestVisible
    private static Integer revenuePoints(Decimal revenue) {
        if (revenue == null)              { return 0; }
        if (revenue >= REVENUE_HIGH)      { return 3; }
        if (revenue >= REVENUE_MEDIUM)    { return 2; }
        if (revenue >= REVENUE_LOW)       { return 1; }
        return 0;
    }

    /**
     * @description Returns employee-count-based points.
     *
     * @param  employees  NumberOfEmployees value (may be null).
     * @return            0-3 points.
     */
    @TestVisible
    private static Integer employeePoints(Integer employees) {
        if (employees == null)          { return 0; }
        if (employees >= EMP_HIGH)      { return 3; }
        if (employees >= EMP_MEDIUM)    { return 2; }
        if (employees >= EMP_LOW)       { return 1; }
        return 0;
    }

    /**
     * @description Returns opportunity-based points (1 point if at least one
     *              open Opportunity exists, 0 otherwise).
     *
     * @param  opps  Sub-queried Opportunities list.
     * @return       0 or 1 point.
     */
    @TestVisible
    private static Integer opportunityPoints(List<Opportunity> opps) {
        return (opps != null && !opps.isEmpty()) ? OPP_POINTS : 0;
    }

    /**
     * @description Derives the rating label from a numeric score.
     *
     * @param  score  Computed integer score.
     * @return        'Hot', 'Warm', or 'Cold'.
     */
    @TestVisible
    private static String deriveRating(Integer score) {
        if (score >= HOT_THRESHOLD)  { return RATING_HOT;  }
        if (score >= WARM_THRESHOLD) { return RATING_WARM; }
        return RATING_COLD;
    }
}