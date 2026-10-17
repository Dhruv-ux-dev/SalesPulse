@IsTest
private class LeadRoutingActionTest {
    @IsTest
    static void scoreAndAssignCalculatesScoreAndRating() {
        Lead sample = new Lead(
            LastName = 'Sample Lead',
            Company = 'Acme Analytics',
            Industry = 'Technology',
            AnnualRevenue = 1500000,
            NumberOfEmployees = 250,
            Email = 'lead@acme.example',
            Website = 'https://acme.example',
            LeadSource = 'Partner Referral'
        );
        Integer expectedScore = 90; // 20 + 20 + 15 + 10 + 10 + 15
        System.assertEquals(expectedScore, LeadRoutingAction.calculateScore(sample));
        sample.Email = null;
        sample.Website = null;
        sample.Industry = 'Other';
        sample.LeadSource = 'Other';
        sample.AnnualRevenue = null;
        sample.NumberOfEmployees = null;
        System.assertEquals(0, LeadRoutingAction.calculateScore(sample));
    }

    @IsTest
    static void invocableProcessesManyLeads() {
        List<Lead> leads = new List<Lead>{
            new Lead(LastName='High Intent', Company='Northstar', Industry='Technology', Email='hi@northstar.example', LeadSource='Web'),
            new Lead(LastName='Low Intent', Company='Small Co', Industry='Other', LeadSource='Other', Phone='555-0100')
        };
        insert leads;

        List<LeadRoutingAction.Request> requests = new List<LeadRoutingAction.Request>();
        for (Lead leadRecord : leads) {
            LeadRoutingAction.Request requestItem = new LeadRoutingAction.Request();
            requestItem.leadId = leadRecord.Id;
            requests.add(requestItem);
        }

        Test.startTest();
        LeadRoutingAction.scoreAndAssign(requests);
        Test.stopTest();

        Map<Id, Lead> refreshed = new Map<Id, Lead>([
            SELECT Id, Lead_Score__c, Lead_Rating__c
            FROM Lead WHERE Id IN :leads
        ]);
        System.assertEquals(Decimal.valueOf('40'), refreshed.get(leads[0].Id).Lead_Score__c);
        System.assertEquals('Warm', refreshed.get(leads[0].Id).Lead_Rating__c);
        System.assertEquals(Decimal.valueOf('0'), refreshed.get(leads[1].Id).Lead_Score__c);
        System.assertEquals('Cold', refreshed.get(leads[1].Id).Lead_Rating__c);
    }
}
