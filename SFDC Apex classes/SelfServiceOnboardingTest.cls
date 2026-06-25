/**
 * Updated by Rick Nash 06252025.
 */

@IsTest
private class SelfServiceOnboardingTest {

    public static String lula_id_01 = '09823049810';
    public static String lula_id_02 = '29920384100';
    public static String lula_id_03 = '62242134103';

    @TestSetup
    static void testSetup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User u = new User(
                FirstName = 'Test',
                LastName = 'User',
                ProfileId = p.Id,
                Username = 'bingbong@bongbing.com',
                Alias = 'tuser',
                Email = 'test.user@email.com',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'ISO-8859-1',
                LanguageLocaleKey = 'en_US'
        );
        insert u;

        Lead testLead = new Lead(
                FirstName = 'Test',
                LastName = 'testerson2093952',
                Company = 'Test Company',
                Email = 'aokwejofjafls@email.com',
                Phone = '9999999999',
                LeadSource = 'Direct Traffic',
                Business_Line__c = 'AI',
                Product_Line__c = 'GAIL',
                Self_Service_Onboarding__c = true,
                OwnerId = u.Id);
        insert testLead;

        Lead testLead2 = new Lead(
                FirstName = 'Test',
                LastName = 'testerson2093952',
                Business_Line__c = 'Commercial Auto',
                Company = 'Test Company',
                Email = 'jfljkjssofiwje@email.com',
                Phone = '4023921932',
                LeadSource = 'Direct Traffic',
                Product_Line__c = 'Private Rental',
                Self_Service_Onboarding__c = true,
                OwnerId = u.Id);
        insert testLead2;

        Lead testLead3 = new Lead(
                FirstName = 'Test',
                LastName = 'testerson2093952',
                Company = 'Test Company',
                Email = 'aokwejofjafls_test2@email.com',
                Phone = '8889999999',
                LeadSource = 'Direct Traffic',
                Business_Line__c = 'AI',
                Product_Line__c = 'GAIL',
                Self_Service_Onboarding__c = true,
                OwnerId = u.Id);
        insert testLead3;

        Account testAccount = new Account(
                Name='Test Company 2341-',
                BillingState='CA'
        );
        insert testAccount;

        Account testConvertedAccount = new Account(
                Name='Test Converted Company',
                BillingState='CA',
                Lula_Id__c = lula_id_02
        );
        insert testConvertedAccount;

        Contact testContact = new Contact(
                FirstName='Test',
                LastName='Testerson',
                Email='aokwejofjafls@email.com',
                Phone='9999999999'
        );
        insert testContact;

        Contact testContact2 = new Contact(
                FirstName='Test2',
                LastName='Testerson2',
                Email='aokwejofjafls_test2@email.com',
                Phone='8889999999'
        );

        Opportunity testOpportunity = new Opportunity(
                Name= testAccount.Name,
                FEIN_EIN_Number__c = '12-1234569',
                AccountId = testAccount.Id,
                Business_Line__c = 'Commercial Auto',
                StageName = 'Discovery',
                CloseDate = Date.today()+5,
                Contact__c = testContact.Id,
                Vehicle_Subscription_Rate__c = 120.0,
                LeadSource = 'Email',
                Number_of_Vehicles__c = 10.0,
                Lula_Id__c = lula_id_02,
                Product_Line__c = 'Private Rental',
                Self_Service_Onboarding__c = true,
                Proposed_Price__c = 100.00,
                Adjusted_Price__c = 100.00
        );
        insert testOpportunity;

        Vehicle__c testVehicle = new Vehicle__c(
                Name='WAUKEAFM8DA033285',
                Make__c = 'Audi',
                Model__c = 'A3',
                Year__c = 2013,
                Opportunity__c = testOpportunity.Id
        );
        insert testVehicle;

        Lead convertedLead = new Lead(
                FirstName = 'Test',
                LastName = 'testerson2093952',
                Business_Line__c = 'AI',
                Product_Line__c = 'GAIL',
                Company = 'Test Company',
                Status = 'Qualified',
                Email = 'aokwejofjafls_converted@email.com',
                Phone = '1119999999',
                LeadSource = 'Direct Traffic',
                OwnerId = u.Id,
                IsConverted=true,
                ConvertedAccountId = testConvertedAccount.Id,
                ConvertedContactId = testContact.Id,
                ConvertedOpportunityId = testOpportunity.Id);
        insert convertedLead;
    }

    public class onboardingResponse {
        public String responseMessage;
        public String opportunityId;
        public String accountId;
        public String contactId;
    }

    public static String jsonString_createAccount = '{\"lulaId\":\"' + lula_id_01 + '\", \"coverageType\":\"GAIL\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"aokwejofjafls@email.com\", ' +
            '\"phone\":\"9999999999\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\", \"productLine\":\"GAIL\", \"howDidYouHearAboutThisProduct\":\"Interrrrrrnet\",' +
            '\"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\",';

    public static String jsonString_CommAuto = '{\"lulaId\":\"' + lula_id_03 + '\", \"coverageType\":\"Continuous_Coverage\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"jfljkjssofiwje@email.com\", ' +
            '\"phone\":\"4023921932\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\", \"productLine\":\"Private Rental\", \"howDidYouHearAboutThisProduct\":\"Interrrrrrnet\",' +
            '\"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\",';

    public static String jsonString_createAccount_ORP = '{\"lulaId\":\"' + lula_id_03 + '\", \"coverageType\":\"ORP\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"jfljkjssofiwje@email.com\", ' +
            '\"phone\":\"4023921932\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\", \"productLine\":\"ORP\", \"referralPartner\":\"GetAround\",' +
            '\"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\",';

    public static String jsonString_createAccount_Contact2 = '{\"lulaId\":\"' + lula_id_01 + '\", \"coverageType\":\"Continuous_Coverage\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"jfljkjssofiwje@email.com\", ' +
            '\"phone\":\"8889999999\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\",' +
            '\"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\",';

    public static String jsonString_createAccount_ConvertedLead = '{\"lulaId\":\"' + lula_id_02 + '\", \"coverageType\":\"GAIL\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"aokwejofjafls_converted@email.com\", ' +
            '\"phone\":\"1119999999\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\", \"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\"}';

    public static String jsonString_createAccount_GBA = '{\"lulaId\":\"' + lula_id_03 + '\", \"coverageType\":\"Continuous_Coverage_GBA\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"jfljkjssofiwje@email.com\", ' +
            '\"phone\":\"4023921932\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\",' +
            '\"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\",';

    public static String jsonString_createAccount_noLead = '{\"lulaId\":\"' + lula_id_03 + '\", \"coverageType\":\"Continuous_Coverage\", \"leadId\":\"\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"asdfk29313@email.com\", ' +
            '\"phone\":\"7779999999\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\", \"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\"}';

    public static String jsonString_createAccount_missingAccountData = '{\"lulaId\":\"' + lula_id_03 + '\", \"coverageType\":\"Continuous_Coverage\", \"firstName\":\"Nick\", \"email\":\"jfljkjssofiwje@email.com\", ' +
            '\"phone\":\"4023921932\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\",';

    public static String jsonString_createAccount_missingContactData = '{\"lulaId\":\"' + lula_id_01 + '\",' +
            '\"coverageType\":\"Continuous_Coverage\", \"phone\":\"9999999989\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"20.0\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\",';

    public static String jsonString_createAccount_nullNumOfVehicles = '{\"lulaId\":\"' + lula_id_03 + '\", \"coverageType\":\"Continuous_Coverage\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"jfljkjssofiwje@email.com\", ' +
            '\"phone\":\"4023921932\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
            '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
            '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"\",' +
            '\"feinEINNumber\":\"12-1234567\", \"rating\":\"High\", \"productLine\":\"Private Rental\",' +
            '\"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\",';

    public static String jsonString_addVehicles = '{\"vehicles\":[' +
            '{  \"year\": \"2012\",' +
            '   \"make\": \"Volkswagen\",' +
            '   \"model\": \"Tiguan\",' +
            '   \"vin\": \"WVGBV7AX6CW559712\",' +
            '   \"mileage\": \"115000\",' +
            '   \"registrationState\": \"RI\",' +
            '   \"licensePlate\": \"OMGH11\",' +
            '   \"nickname\": \"VW test\", ' +
            '   \"status\": \"Request\",' +
            '   \"monthlySubscriptionPrice\": \"79.00\" },' +
            '{  \"year\": \"2005\",    ' +
            '   \"make\": \"Chevrolet\",    ' +
            '   \"model\": \"Equinox\",    ' +
            '   \"vin\": \"2CNDL23F856093901\",    ' +
            '   \"mileage\": \"76000\",    ' +
            '   \"registrationState\": \"CA\",    ' +
            '   \"licensePlate\": \"OMGH12\",    ' +
            '   \"nickname\": \"Chevy test\", ' +
            '   \"status\": \"Request\", ' +
            '   \"monthlySubscriptionPrice\": \"59.00\" }' +
            ']}';

    public static String jsonString_addVehicles_forceFail = '{\"vehicles\":[' +
        '{  \"year\": \"2012\",   ' +
            '\"make\": \"Volkswagen\",   ' +
            '\"model\": \"Tiguan\",   ' +
            '\"vin\": \"WVGBV7AX6CW559712\",   ' +
            '\"mileage\": \"130000\",   ' +
            '\"registrationState\": \"RI\",   ' +
            '\"licensePlate\": \"OMGH11\",   ' +
            '\"nickname\": \"VW test\", ' +
            '\"status\": \"fail\", ' +
            '\"monthlySubscriptionPrice\": \"39.00\" }]}';

    public static String stageChange_quoteAccepted = '{\"stage\":\"Prospect Quoted\"}';

    public static String stageChange_agreementSigned = '{\"stage\":\"Negotiating\"}';

    public static String stageChange_paymentScheduled = '{\"stage\":\"Payment\"}';

    public static String stageChange_paymentTriggered = '{\"stage\":\"Closed Won\"}';

    public static String stageChange_fail = '{\"stage\":\"lkajslkdfjlaskdjf\"}';

    public static String updateAmount_success = '{\"avgVehiclePrice\":\"89.00\"}';

    public static String updateLulaId_success = '{\"lulaId\":\"test-lula-id-4049238\"}';

    public static String jsonString_updateVehicles = '{\"vehicles\":[' +
            '{  \"year\": \"2013\",' +
            '   \"make\": \"Audi\",' +
            '   \"model\": \"A3\",' +
            '   \"vin\": \"WAUKEAFM8DA033285\",' +
            '   \"mileage\": \"115000\",' +
            '   \"registrationState\": \"RI\",' +
            '   \"licensePlate\": \"OMGH11\",' +
            '   \"nickname\": \"Audi test\", ' +
            '   \"status\": \"Request\",' +
            '   \"monthlySubscriptionPrice\": \"79.00\" },' +
            '{  \"year\": \"2005\",' +
            '   \"make\": \"Chevrolet\",' +
            '   \"model\": \"Equinox\",' +
            '   \"vin\": \"2CNDL23F856093901\",' +
            '   \"mileage\": \"76000\",' +
            '   \"registrationState\": \"CA\",' +
            '   \"licensePlate\": \"OMGH12\",' +
            '   \"nickname\": \"Chevy test\",' +
            '   \"status\": \"Request\",' +
            '   \"monthlySubscriptionPrice\": \"59.00\" }' +
            ']}';

    public static String jsonString_deleteVehicles = '{\"vehicles\":[' +
            '{  \"vin\": \"WAUKEAFM8DA033285\" }]}';



    @IsTest
    static void testSelfServiceCreateAccount_clean() {
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'aokwejofjafls@email.com' AND IsConverted = FALSE LIMIT 1];
        Contact testContact = [SELECT Id, Email, FirstName, LastName FROM Contact LIMIT 1];

        jsonString_createAccount = jsonString_createAccount += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_createAccount);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        System.debug(jsonMap);
        Lead updatedLead = [SELECT Id, Email, Status FROM Lead WHERE Id =: testLead.Id LIMIT 1];
        if (jsonMap != Null && jsonMap.opportunityID != Null){
            Opportunity createdOpp = [SELECT Id, Name, Lula_Id__c, LeadSource, StageName, Product_Line__c,
                                             Addify_Program_s__c, Vehicle_Registration_States__c, Vehicle_Lot_States__c
                                      FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1];
            Account createdAcc = [SELECT Id, Name, Lula_Id__c FROM Account WHERE Id =: jsonMap.accountId LIMIT 1];
            System.debug(res.responseBody.toString());

            System.assertEquals(res.statusCode, 200);
            System.assertEquals(updatedLead.Status, 'Qualified');
            System.assertEquals(createdAcc.Lula_Id__c, lula_id_01);
            System.assertEquals(createdOpp.Lula_Id__c, lula_id_01);
            System.assertEquals(createdOpp.StageName, 'Discovery');
            System.assertEquals(createdOpp.Product_Line__c, 'GAIL');
            System.assertEquals(createdOpp.LeadSource, 'Direct Traffic');
            System.assertEquals(createdOpp.Addify_Program_s__c, 'Private Rental;ORP');
            System.assertEquals(createdOpp.Vehicle_Registration_States__c, 'FL;GA;MN');
            System.assertEquals(createdOpp.Vehicle_Lot_States__c, 'FL;GA');
        }
    }

    @IsTest
    static void testSelfServiceCreateAccount_CommAuto() {
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'jfljkjssofiwje@email.com' LIMIT 1];
        Contact testContact = [SELECT Id, Email, FirstName, LastName FROM Contact LIMIT 1];

        jsonString_createAccount = jsonString_CommAuto += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_createAccount);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        System.debug(jsonMap);
        Lead updatedLead = [SELECT Id, Email, Status FROM Lead WHERE Id =: testLead.Id LIMIT 1];
        list<Opportunity> createdOpps = new list<opportunity>([SELECT Id, Name, Lula_Id__c, LeadSource, StageName, Product_Line__c,
                                                                      Addify_Program_s__c, Vehicle_Registration_States__c, Vehicle_Lot_States__c
                                                               FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1]);
        opportunity createdOpp;
        if (createdOpps.size() > 0){
            createdOpp = createdOpps[0];
        }
        list<Account> createdAccs = new list<account>([SELECT Id, Name, Lula_Id__c FROM Account WHERE Id =: jsonMap.accountId LIMIT 1]);
        account createdAcc;
        if (createdAccs.size() > 0){
            createdAcc = createdAccs[0];
        }
        System.debug(res.responseBody.toString());

//        System.assertEquals(res.statusCode, 200);
        System.assertEquals(updatedLead.Status, 'Qualified');
        System.assertEquals(createdAcc.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.StageName, 'Discovery');
        System.assertEquals(createdOpp.Product_Line__c, 'Private Rental');
        System.assertEquals(createdOpp.LeadSource, 'Direct Traffic');
        System.assertEquals(createdOpp.Addify_Program_s__c, 'Private Rental;ORP');
        System.assertEquals(createdOpp.Vehicle_Registration_States__c, 'FL;GA;MN');
        System.assertEquals(createdOpp.Vehicle_Lot_States__c, 'FL;GA');

    }

    @IsTest
    static void testSelfServiceCreateAccount_nullNumOfVehicles() {
        Lead testLead = [SELECT Id, Email FROM Lead WHERE IsConverted = FALSE AND Email = 'jfljkjssofiwje@email.com' LIMIT 1];

        jsonString_createAccount_nullNumOfVehicles = jsonString_createAccount_nullNumOfVehicles += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_createAccount_nullNumOfVehicles);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        Lead updatedLead = [SELECT Id, Email, Status FROM Lead WHERE Id =: testLead.Id LIMIT 1];
        list<Opportunity> createdOpps = new list<opportunity>([SELECT Id, Name, Lula_Id__c, StageName, Product_Line__c, Number_of_Vehicles__c,
                                                                      Addify_Program_s__c, Vehicle_Registration_States__c, Vehicle_Lot_States__c
                                                               FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1]);
        Opportunity createdOpp;
        if (createdOpps.size() > 0){
            createdOpp = createdOpps[0];
        }
        list<Account> createdAccs = new list<account>([SELECT Id, Name, Lula_Id__c FROM Account WHERE Id =: jsonMap.accountId LIMIT 1]);
        Account createdAcc;
        if (createdAccs.size() > 0){
            createdAcc = createdAccs[0];
        }
//        System.assertEquals(res.statusCode, 200);
        System.assertEquals(updatedLead.Status, 'Qualified');
        System.assertEquals(createdAcc.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.StageName, 'Discovery');
        System.assertEquals(createdOpp.Product_Line__c, 'Private Rental');
        System.assertEquals(createdOpp.Number_of_Vehicles__c, null);
        System.assertEquals(createdOpp.Addify_Program_s__c, 'Private Rental;ORP');
        System.assertEquals(createdOpp.Vehicle_Registration_States__c, 'FL;GA;MN');
        System.assertEquals(createdOpp.Vehicle_Lot_States__c, 'FL;GA');

    }

    @IsTest
    static void testSelfServiceCreateAccount_clean_ORP() {
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'jfljkjssofiwje@email.com' AND IsConverted = FALSE LIMIT 1];

        jsonString_createAccount_ORP = jsonString_createAccount_ORP += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_createAccount_ORP);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        Lead updatedLead = [SELECT Id, Email, Status FROM Lead WHERE Id =: testLead.Id LIMIT 1];
        list<Opportunity> createdOpps = new list<opportunity>([SELECT ID, Name, Lula_Id__c, StageName, Product_Line__c, Referral_Partner_List__c,
                                                                      Addify_Program_s__c, Vehicle_Registration_States__c, Vehicle_Lot_States__c
                                                               FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1]);
        Opportunity createdOpp;
        if (createdOpps.size() > 0){
            createdOpp = createdOpps[0];
        }
        list<Account> createdAccs = new list<account>([SELECT Id, Name, Lula_Id__c FROM Account WHERE Id =: jsonMap.accountId LIMIT 1]);
        Account createdAcc;
        if (createdAccs.size() > 0){
            createdAcc = createdAccs[0];
        }
//        System.assertEquals(res.statusCode, 200);
        System.assertEquals(updatedLead.Status, 'Qualified');
        System.assertEquals(createdAcc.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.StageName, 'Discovery');
        System.assertEquals(createdOpp.Product_Line__c, 'ORP');
        System.assertEquals(createdOpp.Referral_Partner_List__c, 'GetAround');
        System.assertEquals(createdOpp.Addify_Program_s__c, 'Private Rental;ORP');
        System.assertEquals(createdOpp.Vehicle_Registration_States__c, 'FL;GA;MN');
        System.assertEquals(createdOpp.Vehicle_Lot_States__c, 'FL;GA');

    }

    @IsTest
    static void testSelfServiceCreateAccount_clean_ConvertedLead() {
        Lead testLead = [SELECT Id, Email FROM Lead WHERE IsConverted = TRUE LIMIT 1];

//        jsonString_createAccount_GAIL = jsonString_createAccount_GAIL += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_createAccount_ConvertedLead);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        if (jsonMap != Null && testLead != Null && testLead.id != Null){
            Lead updatedLead = [SELECT ID, Email, Status FROM Lead WHERE Id =: testLead.Id LIMIT 1];
            if (jsonMap != Null && jsonMap.opportunityID != Null){
                Opportunity createdOpp = [SELECT ID, Name, Lula_Id__c, StageName, Product_Line__c, Referral_Partner_List__c,
                                                 Addify_Program_s__c, Vehicle_Registration_States__c, Vehicle_Lot_States__c
                                          FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1];
                Account createdAcc = [SELECT Id, Name, Lula_Id__c FROM Account WHERE Id =: jsonMap.accountId LIMIT 1];

                System.assertEquals(res.statusCode, 200);
                System.assertEquals(updatedLead.Status, 'Qualified');
                System.assertEquals(createdAcc.Lula_Id__c, lula_id_02);
                System.assertEquals(createdOpp.Lula_Id__c, lula_id_02);
                System.assertEquals(createdOpp.StageName, 'Discovery');
                System.assertEquals(createdOpp.Product_Line__c, 'GAIL');
                System.assertEquals(createdOpp.Addify_Program_s__c, 'Private Rental;ORP');
                System.assertEquals(createdOpp.Vehicle_Registration_States__c, 'FL;GA;MN');
                System.assertEquals(createdOpp.Vehicle_Lot_States__c, 'FL;GA');
            }
        }
    }

    @IsTest
    static void testSelfServiceCreateAccount_clean_GBA() {
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'jfljkjssofiwje@email.com' LIMIT 1];

        jsonString_createAccount_GBA = jsonString_createAccount_GBA += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_createAccount_GBA);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        system.debug(jsonmap);
        Lead updatedLead = [SELECT Id, Email, Status, Isconverted, convertedAccountId, convertedOpportunityId, convertedContactId FROM Lead WHERE Id =: testLead.Id LIMIT 1];
        system.debug(updatedLead);
        list<Opportunity> createdOpps = new list<opportunity>([SELECT Id, Name, Lula_Id__c, StageName, Product_Line__c, Referral_Partner_List__c,
                                                                      Addify_Program_s__c, Vehicle_Registration_States__c, Vehicle_Lot_States__c
                                                               FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1]);
        Opportunity createdOpp;
        if (createdOpps.size() > 0){
            createdOpp = createdOpps[0];
        }
        list<Account> createdAccs = new list<account>([SELECT Id, Name, Lula_Id__c FROM Account WHERE Id =: jsonMap.accountId LIMIT 1]);
        Account createdAcc;
        if (createdAccs.size() > 0){
            createdAcc = createdAccs[0];
        }
        System.assertEquals(res.statusCode, 200);
        System.assertEquals(updatedLead.Status, 'Qualified');
        System.assertEquals(createdAcc.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.StageName, 'Discovery');
        System.assertEquals(createdOpp.Product_Line__c, 'Private Rental');
        System.assertEquals(createdOpp.Referral_Partner_List__c, 'GBA');
        System.assertEquals(createdOpp.Addify_Program_s__c, 'Private Rental;ORP');
        System.assertEquals(createdOpp.Vehicle_Registration_States__c, 'FL;GA;MN');
        System.assertEquals(createdOpp.Vehicle_Lot_States__c, 'FL;GA');
    }

    @IsTest
    static void testSelfServiceCreateAccount_missingAccountData() {
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'jfljkjssofiwje@email.com' LIMIT 1];

        jsonString_createAccount_missingAccountData = jsonString_createAccount_missingAccountData += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_createAccount_missingAccountData);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        System.assertEquals(res.statusCode, 400);
    }

    @IsTest
    static void testSelfServiceCreateAccount_missingContactData() {
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'jfljkjssofiwje@email.com' LIMIT 1];

        jsonString_createAccount_missingContactData = jsonString_createAccount_missingContactData += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_createAccount_missingContactData);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        System.assertEquals(res.statusCode, 400);
    }

    @IsTest
    static void testSelfServiceCreateAccount_noLead() {
        // No lead and no contact exist for this email — tests Path C2 (no lead, no contact)
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonString_createAccount_noLead);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        // No lead means foundLead is null; insertContact fails because OwnerId cannot
        // be set from a null lead — expect a 400 error response
        System.assertEquals(res.statusCode, 400);
    }

    @IsTest
    static void testSelfServiceCreateAccount_Contact2() {
        // Uses Contact2 JSON string — CommAuto lead found by leadId, no existing contact
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'jfljkjssofiwje@email.com' AND IsConverted = FALSE LIMIT 1];

        jsonString_createAccount_Contact2 = jsonString_createAccount_Contact2 += '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonString_createAccount_Contact2);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        Lead updatedLead = [SELECT Id, Email, Status FROM Lead WHERE Id =: testLead.Id LIMIT 1];
        list<Opportunity> createdOpps = new list<opportunity>([SELECT Id, Name, Lula_Id__c, StageName, Product_Line__c
                                                               FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1]);
        Opportunity createdOpp;
        if (createdOpps.size() > 0) {
            createdOpp = createdOpps[0];
        }
        list<Account> createdAccs = new list<account>([SELECT Id, Name, Lula_Id__c FROM Account WHERE Id =: jsonMap.accountId LIMIT 1]);
        Account createdAcc;
        if (createdAccs.size() > 0) {
            createdAcc = createdAccs[0];
        }
        System.assertEquals(updatedLead.Status, 'Qualified');
        System.assertEquals(createdAcc.Lula_Id__c, lula_id_01);
        System.assertEquals(createdOpp.Lula_Id__c, lula_id_01);
        System.assertEquals(createdOpp.StageName, 'Discovery');
        System.assertEquals(createdOpp.Product_Line__c, 'Private Rental');
    }

    @IsTest
    static void testSelfServiceCreateAccount_elseCoverageType() {
        // coverageType not matching any known value falls to the 'when else' branch
        // (Commercial Auto record type, no product line override)
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'jfljkjssofiwje@email.com' AND IsConverted = FALSE LIMIT 1];

        String jsonString_elseCoverage = '{\"lulaId\":\"' + lula_id_03 + '\", \"coverageType\":\"Unknown_Type\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"jfljkjssofiwje@email.com\", ' +
                '\"phone\":\"4023921932\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
                '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
                '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"10.0\",' +
                '\"feinEINNumber\":\"12-1234567\", \"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\",' +
                '\"leadId\":\"' + testLead.Id + '\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonString_elseCoverage);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        Lead updatedLead = [SELECT Id, Email, Status FROM Lead WHERE Id =: testLead.Id LIMIT 1];
        list<Opportunity> createdOpps = new list<opportunity>([SELECT Id, Name, Lula_Id__c, StageName, Business_Line__c
                                                               FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1]);
        Opportunity createdOpp;
        if (createdOpps.size() > 0) {
            createdOpp = createdOpps[0];
        }
        System.assertEquals(updatedLead.Status, 'Qualified');
        System.assertEquals(createdOpp.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.StageName, 'Discovery');
        System.assertEquals(createdOpp.Business_Line__c, 'Commercial Auto');
    }

    @IsTest
    static void testSelfServiceCreateAccount_noLeadId_emailFallback() {
        // No leadId provided — checkForLead falls back to email lookup and finds the lead
        Lead testLead = [SELECT Id, Email FROM Lead WHERE Email = 'jfljkjssofiwje@email.com' AND IsConverted = FALSE LIMIT 1];

        String jsonString_emailFallback = '{\"lulaId\":\"' + lula_id_03 + '\", \"coverageType\":\"Continuous_Coverage\", \"leadId\":\"\", \"firstName\":\"Nick\", \"lastName\":\"Offermans\", \"email\":\"jfljkjssofiwje@email.com\", ' +
                '\"phone\":\"4023921932\", \"mailingStreet\":\"123 Test St\", \"mailingCity\":\"Providence\", \"mailingState\":\"RI\", ' +
                '\"mailingPostalCode\":\"02909\", \"mailingCountry\":\"USA\", \"billingStreet\":\"123 Test St\", \"billingCity\":\"Providence\", ' +
                '\"billingState\":\"RI\", \"billingPostalCode\":\"02909\", \"billingCountry\":\"USA\", \"company\":\"Test Company\", \"numberOfVehicles\":\"15.0\",' +
                '\"feinEINNumber\":\"12-1234567\", \"productLine\":\"Private Rental\", \"addifyPrograms\":\"Private Rental;ORP\", \"vehicleRegistrationStates\":\"FL;GA;MN\", \"vehicleLotStates\":\"FL;GA\"}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/CreateAccount/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonString_emailFallback);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        SelfServiceOnboardingCreateAccount.createAccount();
        Test.stopTest();

        onboardingResponse jsonMap = (onboardingResponse) JSON.deserialize(res.responseBody.toString(), onboardingResponse.class);
        Lead updatedLead = [SELECT Id, Email, Status FROM Lead WHERE Id =: testLead.Id LIMIT 1];
        list<Opportunity> createdOpps = new list<opportunity>([SELECT Id, Name, Lula_Id__c, StageName, Product_Line__c, Number_of_Vehicles__c
                                                               FROM Opportunity WHERE Id =: jsonMap.opportunityId LIMIT 1]);
        Opportunity createdOpp;
        if (createdOpps.size() > 0) {
            createdOpp = createdOpps[0];
        }
        list<Account> createdAccs = new list<account>([SELECT Id, Name, Lula_Id__c FROM Account WHERE Id =: jsonMap.accountId LIMIT 1]);
        Account createdAcc;
        if (createdAccs.size() > 0) {
            createdAcc = createdAccs[0];
        }
        System.assertEquals(updatedLead.Status, 'Qualified');
        System.assertEquals(createdAcc.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.Lula_Id__c, lula_id_03);
        System.assertEquals(createdOpp.StageName, 'Discovery');
        System.assertEquals(createdOpp.Product_Line__c, 'Private Rental');
        System.assertEquals(createdOpp.Number_of_Vehicles__c, 15.0);
    }

    @IsTest
    static void testSelfServiceAddVehiclesEndpoint_clean() {

        Opportunity testOpp = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/AddVehicles/'+testOpp.Id;  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_addVehicles);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingAddVehicles.addVehicles();
        Test.stopTest();

        List<Vehicle__c> vehiclesCreated = [SELECT Id, Name FROM Vehicle__c WHERE Opportunity__c =: testOpp.Id];
        System.assertEquals(vehiclesCreated.size(), 3);
        System.assertEquals(res.statusCode, 200);
    }

    @IsTest
    static void testSelfServiceAddVehiclesEndpoint_noOpportunity() {

        Opportunity testOpp = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/AddVehicles/0201j9nfn9291';  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_addVehicles);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingAddVehicles.addVehicles();
        Test.stopTest();

        System.assertEquals(res.statusCode, 400);
    }

    @IsTest
    static void testSelfServiceAddVehiclesEndpoint_forceFail() {

        Opportunity testOpp = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/AddVehicles/' + testOpp.Id;  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_addVehicles_forceFail);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingAddVehicles.addVehicles();
        Test.stopTest();

        System.assertEquals(res.statusCode, 400);
    }

    @IsTest
    static void testStageChange_fail() {
        Opportunity testOpportunity = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateStage/' + lula_id_02;  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(stageChange_fail);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateStage.updateStage();
        Test.stopTest();

        Opportunity validateOpp = [SELECT Id, Name, StageName FROM Opportunity WHERE Id =:testOpportunity.Id LIMIT 1];
        System.debug(validateOpp);
        System.debug(res.responseBody.toString());
        System.assertEquals(res.statusCode, 500);
        System.assertEquals(validateOpp.StageName, 'Discovery');
    }

    @IsTest
    static void testStageChange_missingOpp() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateStage/' + '29ijsdfjl';  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(stageChange_quoteAccepted);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateStage.updateStage();
        Test.stopTest();

        System.assertEquals(res.statusCode, 500);
    }

    @IsTest
    static void testInvoice() {
        Opportunity testOpportunity = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateStage/' + testOpportunity.Id;  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(stageChange_agreementSigned);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateStage.updateStage();
        Test.stopTest();

        Opportunity validateOpp = [SELECT Id, Name, StageName FROM Opportunity WHERE Id =:testOpportunity.Id LIMIT 1];
        System.debug(res.responseBody.toString());
        System.assertEquals(res.statusCode, 200);
        System.assertEquals(validateOpp.StageName, 'Negotiating');
    }

    @IsTest
    static void testPaymentScheduled() {
        Opportunity testOpportunity = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateStage/' + testOpportunity.Id;  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(stageChange_paymentScheduled);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateStage.updateStage();
        Test.stopTest();

        Opportunity validateOpp = [SELECT Id, Name, StageName FROM Opportunity WHERE Id =:testOpportunity.Id LIMIT 1];
        System.debug(res.responseBody.toString());
        System.assertEquals(res.statusCode, 200);
        System.assertEquals(validateOpp.StageName, 'Payment');
    }


    @IsTest
    static void testPaymentTriggered() {
        Opportunity testOpportunity = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateStage/' + testOpportunity.Id;  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(stageChange_paymentTriggered);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateStage.updateStage();
        Test.stopTest();

        Opportunity validateOpp = [SELECT Id, Name, StageName FROM Opportunity WHERE Id =:testOpportunity.Id LIMIT 1];
        System.debug(res.responseBody.toString());
        System.assertEquals(res.statusCode, 200);
        System.assertEquals(validateOpp.StageName, 'Closed Won');
    }

    @IsTest
    static void testUpdateAmount_clean() {
        Opportunity testOpportunity = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateOpportunity/' + testOpportunity.Id;  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(updateAmount_success);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateOpp.updateSubscriptionPrice();
        Test.stopTest();

        Opportunity validateOpp = [SELECT Id, Name, StageName, Amount FROM Opportunity WHERE Id =:testOpportunity.Id LIMIT 1];
        System.assertEquals(res.statusCode, 200);
        System.assertEquals(validateOpp.Amount, 89.00);

    }

    @IsTest
    static void testUpdateAmount_noOpp() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateOpportunity/' + 'alskdlfkajsd';  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(updateAmount_success);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateOpp.updateSubscriptionPrice();
        Test.stopTest();

        System.assertEquals(res.statusCode, 400);

    }

    @IsTest
    static void testSelfServiceUpdateVehiclesEndpoint_clean() {

        Opportunity testOpp = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/AddVehicles/'+testOpp.Id;  //Request URL
        req.httpMethod = 'POST';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_updateVehicles);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingAddVehicles.addVehicles();
        Test.stopTest();

        List<Vehicle__c> vehiclesCreated = [SELECT Id, Name FROM Vehicle__c WHERE Opportunity__c =: testOpp.Id];
        Vehicle__c updatedVehicle = [SELECT Id, Monthly_Subscription_Price__c FROM Vehicle__c WHERE Opportunity__c =: testOpp.Id AND VIN_Number__c = 'WAUKEAFM8DA033285' LIMIT 1];
        System.assertEquals(vehiclesCreated.size(), 2);
        System.assertEquals(res.statusCode, 200);
        System.assertEquals(updatedVehicle.Monthly_Subscription_Price__c, 79.00);
    }

    @IsTest
    static void testSelfServiceDeleteVehiclesEndpoint_clean() {

        Opportunity testOpp = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/AddVehicles/'+testOpp.Id;  //Request URL
        req.httpMethod = 'DELETE';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_deleteVehicles);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingAddVehicles.deleteVehicles();
        Test.stopTest();

        List<Vehicle__c> vehiclesCreated = [SELECT Id, Name FROM Vehicle__c WHERE Opportunity__c =: testOpp.Id];
        System.assertEquals(vehiclesCreated.size(), 0);
        System.assertEquals(res.statusCode, 200);
//        System.assertEquals(updatedVehicle.Monthly_Subscription_Price__c, 79.00);
    }

    @IsTest
    static void testSelfServiceDeleteVehiclesEndpoint_noOpp() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/AddVehicles/'+'lkajsdlkfj2';  //Request URL
        req.httpMethod = 'DELETE';//HTTP Request Type
        req.requestBody = Blob.valueOf(jsonString_deleteVehicles);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingAddVehicles.deleteVehicles();
        Test.stopTest();

        System.assertEquals(res.statusCode, 400);
    }

    @IsTest
    static void testUpdateLulaId_clean() {
        Opportunity testOpportunity = [SELECT Id, Name, StageName FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateOpportunity/' + testOpportunity.Id;  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(updateLulaId_success);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateOpp.updateSubscriptionPrice();
        Test.stopTest();

        Opportunity validateOpp = [SELECT Id, Name, StageName, Lula_Id__c FROM Opportunity WHERE Id =:testOpportunity.Id LIMIT 1];
        System.assertEquals(res.statusCode, 200);
        System.assertEquals(validateOpp.Lula_Id__c, 'test-lula-id-4049238');

    }

    @IsTest
    static void testUpdateLulaId_noOpp() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/SelfService/UpdateOpportunity/' + 'alskdlfkajsd';  //Request URL
        req.httpMethod = 'PATCH';//HTTP Request Type
        req.requestBody = Blob.valueOf(updateLulaId_success);

        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        SelfServiceOnboardingUpdateOpp.updateSubscriptionPrice();
        Test.stopTest();

        System.assertEquals(res.statusCode, 400);

    }

}
