@IsTest
private class AccountEnrichmentServiceTest {
    private class SuccessfulCompanyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assert(request.getEndpoint().startsWith('callout:CompanyData/v1/company?domain='));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"description":"A B2B analytics company","phone":"+1-555-0100","website":"https://acme.example"}');
            return response;
        }
    }

    private class FailedCompanyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(503);
            response.setBody('{"error":"temporarily unavailable"}');
            return response;
        }
    }

    @IsTest
    static void successfulResponseEnrichesAccount() {
        Account accountRecord = new Account(Name='Acme', Website='https://www.acme.example/about');
        insert accountRecord;
        Test.setMock(HttpCalloutMock.class, new SuccessfulCompanyMock());

        Test.startTest();
        AccountEnrichmentService.enrichAccounts(new List<Id>{accountRecord.Id});
        Test.stopTest();

        Account refreshed = [SELECT Description, Phone, Website, Enrichment_Status__c FROM Account WHERE Id=:accountRecord.Id];
        System.assertEquals('A B2B analytics company', refreshed.Description);
        System.assertEquals('+1-555-0100', refreshed.Phone);
        System.assertEquals('https://acme.example', refreshed.Website);
        System.assertEquals('Enriched', refreshed.Enrichment_Status__c);
    }

    @IsTest
    static void unsuccessfulResponseSetsFailedStatus() {
        Account accountRecord = new Account(Name='Unavailable Co', Website='https://unavailable.example');
        insert accountRecord;
        Test.setMock(HttpCalloutMock.class, new FailedCompanyMock());

        Test.startTest();
        AccountEnrichmentService.enrichAccounts(new List<Id>{accountRecord.Id});
        Test.stopTest();

        Account refreshed = [SELECT Enrichment_Status__c FROM Account WHERE Id=:accountRecord.Id];
        System.assertEquals('Failed', refreshed.Enrichment_Status__c);
    }

    @IsTest
    static void domainParserNormalizesWebsite() {
        System.assertEquals('example.com', AccountEnrichmentService.extractDomain('https://www.example.com/path?q=1'));
        System.assertEquals(null, AccountEnrichmentService.extractDomain('  '));
    }
}
