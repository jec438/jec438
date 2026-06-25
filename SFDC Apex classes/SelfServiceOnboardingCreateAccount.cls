/**
 * Updated by Rick Nash 06/10/2025.
 */

@RestResource(urlMapping='/SelfService/CreateAccount/*')
global with sharing class SelfServiceOnboardingCreateAccount {

    public class onboardingRequest{
        public String coverageType;
        public String lulaId;
        public String leadId;
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
        public String mailingStreet;
        public String mailingCity;
        public String mailingState;
        public String mailingPostalCode;
        public String mailingCountry;
        public String billingStreet;
        public String billingCity;
        public String billingState;
        public String billingPostalCode;
        public String billingCountry;
        public String company;
        public String numberOfVehicles;
        public String feinEINNumber;
        public String productLine;
        public String referralPartner;
        public String crm;
        public String ams;
        public String insuranceIndustry;
        public String howDidYouHearAboutThisProduct;
        public String voip;
        public String quotingPlatform;
        public String growsurfParticipantId;
        public String addifyPrograms;
        public String vehicleRegistrationStates;
        public String vehicleLotStates;
    }

    public class onboardingResponse {
        public String responseMessage;
        public String opportunityId;
        public String accountId;
        public String contactId;
    }


    private static Map<String,Object> checkForLead(onboardingRequest onboardingMap) {
        Map<String,Object> responseMap = new Map<String,Object>();

        List<Lead> searchLead = [SELECT Id, Email, Company, Matched_Contact__c, Matched_Account__c, Matched_Opportunity__c, OwnerId, IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId, Business_Line__c FROM Lead WHERE Id =: onboardingMap.leadId LIMIT 1];
        if (!searchLead.isEmpty()) {
            if (onboardingMap.coverageType == 'GAIL' && searchLead[0].Business_Line__c == 'AI') {
                responseMap.put('foundLead', true);
                responseMap.put('leadRecord', searchLead[0]);
            } else if (onboardingMap.coverageType != 'GAIL' && searchLead[0].Business_Line__c == 'Commercial Auto') {
                responseMap.put('foundLead', true);
                responseMap.put('leadRecord', searchLead[0]);
            } else {
                searchLead = [
                SELECT Id, Company, Email, OwnerId, IsConverted, Matched_Contact__c, Matched_Account__c, Matched_Opportunity__c, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId, Business_Line__c
                FROM Lead
                WHERE Email =: onboardingMap.email LIMIT 1];

                if (!searchLead.isEmpty()) {
                    if (onboardingMap.coverageType == 'GAIL' && searchLead[0].Business_Line__c == 'AI') {
                        responseMap.put('foundLead', true);
                        responseMap.put('leadRecord', searchLead[0]);
                    } else if (onboardingMap.coverageType != 'GAIL' && searchLead[0].Business_Line__c == 'Commercial Auto') {
                        responseMap.put('foundLead', true);
                        responseMap.put('leadRecord', searchLead[0]);
                    } else {
                        responseMap.put('foundLead', false);
                    }
                } else {
                        responseMap.put('foundLead', false);
                }
            }
        } else {
            searchLead = [SELECT Id, Email, Company, OwnerId, IsConverted, Matched_Contact__c, Matched_Account__c, Matched_Opportunity__c, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId, Business_Line__c
                FROM Lead WHERE Email != '' AND Email =: onboardingMap.email LIMIT 1];

            if (!searchLead.isEmpty()) {
                if (onboardingMap.coverageType == 'GAIL' && searchLead[0].Business_Line__c == 'AI') {
                    responseMap.put('foundLead', true);
                    responseMap.put('leadRecord', searchLead[0]);
                } else if (onboardingMap.coverageType != 'GAIL' && searchLead[0].Business_Line__c == 'Commercial Auto') {
                    responseMap.put('foundLead', true);
                    responseMap.put('leadRecord', searchLead[0]);
                } else {
                    responseMap.put('foundLead', false);
                }
            } else {
                    responseMap.put('foundLead', false);
            }

        }
        return responseMap;
    }

    private static Map<String,Object> checkForContact(onboardingRequest onboardingMap) {

        Map<String,Object> responseMap = new Map<String,Object>();

        List<Contact> searchContact = [
                SELECT Id, AccountId, OwnerId, Email, FirstName, LastName FROM Contact
                WHERE Email =: onboardingMap.email LIMIT 1];

        if (!searchContact.isEmpty()) {
            responseMap.put('foundContact', true);
            responseMap.put('contactRecord', searchContact[0]);
        } else {
            responseMap.put('foundContact', false);
        }

        return responseMap;
    }

    private static Map<String,Object> checkForOCR(String opportunityId, String contactId) {

        Map<String,Object> responseMap = new Map<String,Object>();

        List<OpportunityContactRole> searchOCR = [
                SELECT Id, ContactId, OpportunityId FROM OpportunityContactRole
                WHERE OpportunityId =: opportunityId AND ContactId =: contactId LIMIT 1];

        if (!searchOCR.isEmpty()) {
            responseMap.put('foundOCR', true);
            responseMap.put('ocr', searchOCR[0]);
        } else {
            responseMap.put('foundOCR', false);
        }

        return responseMap;
    }


    private static Account insertAccount(onboardingRequest jsonMap, String businessLine, String ownerId,
            Contact foundContact, String requestBody, onboardingResponse responseObject, RestResponse response, Account existingAccount, String dmlType) {
        Boolean result;
        string restresponsetxt = '';
        try {
            Account foundAccount = new Account();

            if (string.isnotblank(jsonMap.company)) foundAccount.Name = jsonMap.company;
            if (string.isnotblank(jsonMap.lulaId)) foundAccount.Lula_Id__c = jsonMap.lulaId;
            if (string.isnotblank(businessLine)) foundAccount.Business_Line__c = businessLine;
            if (string.isnotblank(jsonMap.company)) foundAccount.DBA_Name__c = jsonMap.company;
            if (string.isnotblank(jsonMap.phone)) foundAccount.Phone = jsonMap.phone;
            if (string.isnotblank(jsonMap.billingStreet)) foundAccount.BillingStreet = jsonMap.billingStreet;
            if (string.isnotblank(jsonMap.billingCity)) foundAccount.BillingCity = jsonMap.billingCity;
            if (string.isnotblank(jsonMap.billingState)) foundAccount.BillingState = jsonMap.billingState;
            if (string.isnotblank(jsonMap.billingPostalCode)) foundAccount.BillingPostalCode = jsonMap.billingPostalCode;
            if (string.isnotblank(jsonMap.billingCountry)) foundAccount.BillingCountry = jsonMap.billingCountry;
            if (string.isnotblank(jsonMap.mailingStreet)) foundAccount.ShippingStreet = jsonMap.mailingStreet;
            if (string.isnotblank(jsonMap.mailingCity)) foundAccount.ShippingCity = jsonMap.mailingCity;
            if (string.isnotblank(jsonMap.mailingState)) foundAccount.ShippingState = jsonMap.mailingState;
            if (string.isnotblank(jsonMap.mailingPostalCode)) foundAccount.ShippingPostalCode = jsonMap.mailingPostalCode;
            if (string.isnotblank(jsonMap.mailingCountry)) foundAccount.ShippingCountry = jsonMap.mailingCountry;
            if (string.isnotblank(jsonMap.feinEINNumber)) foundAccount.FEIN_EIN_Number__c = jsonMap.feinEINNumber;
            foundAccount.OwnerId = ownerId;
            if (string.isblank(foundAccount.Name)) foundAccount.Name = 'Temp Name - ' + string.valueof(system.today().format());
            switch on dmlType {
                when 'update' {
                    if (existingAccount != Null && existingAccount.id != Null){
                        foundAccount.Id = existingAccount.Id;
                        if (existingAccount.Name != jsonMap.company){
                            UtilityFunctions.logApplicationMismatch('SelfServiceOnboardingCreateAccount/insertAccount', 'Account', 'Name', existingAccount.Name, 'jsonMap.company (Account)', 'Name', jsonMap.company, existingAccount.id, existingAccount.id);
                        }
                    } else {
                        foundAccount.Id = foundContact.AccountId;
                    }
                    update foundAccount;
                }
                when 'insert' {
                    insert foundAccount;
                }
            }

            System.debug(foundAccount);

            return foundAccount;
        } catch (Exception e) {
            String subject = 'Account Failed To Create - Self Service';
            String description = 'Request Body:' + requestBody + '\n'
                    + 'Error Message: ' + e.getMessage();
            String origin = 'Web';
            UtilityFunctions.createCase(subject, origin, description);
            System.debug(description);
            responseObject.responseMessage = description;
            response.statusCode = 400;
            restresponsetxt = JSON.serialize(responseObject);
            response.responseBody = Blob.valueOf(JSON.serialize(responseObject));

            Rest_Endpoint_Info__c RE = new Rest_Endpoint_Info__c();
            RE.requestBody__c = requestbody;
            RE.requestBody_Trimmed__c = requestbody.left(255);
            RE.Request_URI__c = System.RestContext.request.requestURI;
            RE.URI_Id__c = '';
            RE.Apex_Class__c = 'SelfServiceOnboardingCreateAccount';
            RE.Apex_Class_Method__c = 'insertAccount';
            RE.Type__c = 'Post';
            RE.URL_Mapping__c = '/SelfService/CreateAccount/*';
            RE.RestResponse__c = restresponsetxt.left(255);
            insert RE;

            return null;
        }
    }

    private static Contact insertContact(onboardingRequest jsonMap, String businessLine, Account foundAccount, Lead foundLead, Contact existingContact,

            String requestBody, onboardingResponse responseObject, RestResponse response, String dmlType) {
        string restresponsetxt = '';
        try {
            Contact foundContact = new Contact();

            if (string.isnotblank(jsonMap.firstName)) foundContact.FirstName = jsonMap.firstName;
            if (string.isnotblank(jsonMap.lastName)) foundContact.LastName = jsonMap.lastName;
            if (string.isnotblank(jsonMap.email)) foundContact.Email = jsonMap.email;
            if (string.isnotblank(jsonMap.phone)) foundContact.Phone = jsonMap.phone;
            if (string.isnotblank(jsonMap.mailingStreet)) foundContact.MailingStreet = jsonMap.mailingStreet;
            if (string.isnotblank(jsonMap.mailingCity)) foundContact.MailingCity = jsonMap.mailingCity;
            if (string.isnotblank(jsonMap.mailingState)) foundContact.MailingState = jsonMap.mailingState;
            if (string.isnotblank(jsonMap.mailingPostalCode)) foundContact.MailingPostalCode = jsonMap.mailingPostalCode;
            if (string.isnotblank(jsonMap.mailingCountry)) foundContact.MailingCountry = jsonMap.mailingCountry;
            foundContact.AccountId = foundAccount.Id;
            foundContact.OwnerId = foundLead.OwnerId;

            switch on dmlType {
                when 'update' {
                    foundContact.Id = existingContact.Id;
                    if (existingContact.Email != jsonMap.email){
                            UtilityFunctions.logApplicationMismatch('SelfServiceOnboardingCreateAccount/insertContact', 'Contact', 'Email', existingContact.Email, 'jsonMap.email (Contact)', 'Email', jsonMap.email, existingContact.id, existingContact.id);
                    }
                    update foundContact;
                }
                when 'insert' {
                    insert foundContact;
                }
            }

            return foundContact;
        } catch (Exception e) {
            String subject = 'Contact Failed to Create - Self Service';
            String description = 'Request Body:' + requestBody + '\n'
                    + 'Error Message: ' + e.getMessage();
            String origin = 'Web';
            UtilityFunctions.createCase(subject, origin, description);
            System.debug(description);
            responseObject.responseMessage = description;
            response.statusCode = 400;
            restresponsetxt = JSON.serialize(responseObject);
            response.responseBody = Blob.valueOf(JSON.serialize(responseObject));

            Rest_Endpoint_Info__c RE = new Rest_Endpoint_Info__c();
            RE.requestBody__c = requestbody;
            RE.requestBody_Trimmed__c = requestbody.left(255);
            RE.Request_URI__c = System.RestContext.request.requestURI;
            RE.URI_Id__c = '';
            RE.Apex_Class__c = 'SelfServiceOnboardingCreateAccount';
            RE.Apex_Class_Method__c = 'insertContact - failed to create contact';
            RE.Type__c = 'Post';
            RE.URL_Mapping__c = '/SelfService/CreateAccount/*';
            RE.RestResponse__c = restresponsetxt.left(255);
            insert RE;

            return null;
        }
    }

    /*
    - check for lead
    - lead exists not converted:
        - check for existing contact
        - if contact exists check if it has an account
            - no account (growsurf) :
                - create account
                - update contact with account relationship
                - convert lead and assign Account / Contact to conversion
                - convert step creates opportunity and OCR
            - account found (not growsurf) :
                - convert lead and assign Account / Contact to conversion
                - convert step creates opportunity and OCR

    - lead exists converted:
        - pull contact / account / opportunity from conversion results
        - update account
        - update contact
        - update opp

     */

    @HttpPost
    global static void createAccount() {
        onboardingResponse responseObject = new onboardingResponse();
        string restresponsetxt = '';

        RestResponse response = RestContext.response;
        String requestBody = System.RestContext.request.requestBody.toString();

        onboardingRequest jsonMap = (onboardingRequest) JSON.deserialize(requestBody, onboardingRequest.class);

        String businessLine;
        String productLine = jsonMap.productLine;
        String partner = jsonMap.referralPartner;
        Id recordTypeId;
        String leadSource;
        if (jsonMap.coverageType != '') {
            switch on jsonMap.coverageType {
                when 'Continuous_Coverage' {
                    businessLine = 'Commercial Auto';
                    productLine = 'Private Rental';
                    RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND Name = 'Commercial Auto'];
                    recordTypeId = rt.Id;
                }
                when 'Continuous_Coverage_GBA' {
                    businessLine = 'Commercial Auto';
                    partner = 'GBA';
                    leadSource = 'Partner';
                    productLine = 'Private Rental';
                    RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND Name = 'Commercial Auto'];
                    recordTypeId = rt.Id;
                }
                when 'ORP' {
                    businessLine = 'Commercial Auto';
                    productLine = 'ORP';
                    RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND Name = 'Commercial Auto'];
                    recordTypeId = rt.Id;
                }
                when 'GAIL' {
                    productLine = 'GAIL';
                    businessLine = 'AI';
                    RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND Name = 'AI'];
                    recordTypeId = rt.Id;
                }
                when else {
                    businessLine = 'Commercial Auto';
                    RecordType rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND Name = 'Commercial Auto'];
                    recordTypeId = rt.Id;
                }
            }
        }

        Lead foundLead;
        Contact foundContact;
        Account foundAccount;
        Opportunity foundOpportunity;
        Opportunity inflightopp;

        Map<String,Object> checkForLead = checkForLead(jsonMap);
        Map<String,Object> checkForContact = checkForContact(jsonMap);

        if ((Boolean) checkForLead.get('foundLead')) {
            foundLead = (Lead) checkForLead.get('leadRecord');
            system.debug(foundLead);

            if (!foundLead.IsConverted) {
                system.debug('foundLead not converted');
                if (foundLead.Matched_Contact__c != Null){
                    foundContact = [SELECT Id, AccountId, OwnerId, Email, FirstName, LastName from Contact WHERE Id = :foundLead.Matched_Contact__c limit 1];
                }
                if (foundLead.Matched_Account__c != Null){
                    foundAccount = [SELECT Id, Name, OwnerId from Account WHERE Id = :foundLead.Matched_Account__c limit 1];
                }
                if (foundLead.Matched_Opportunity__c != Null){
                    foundOpportunity = [SELECT Id, Name, OwnerId, CloseDate, StageName from Opportunity WHERE Id = :foundLead.Matched_Opportunity__c limit 1];
                }
                if (foundContact != Null && foundAccount != Null){
                    foundAccount = insertAccount(jsonMap,  businessLine, foundLead.OwnerId, foundContact, requestBody, responseObject, response, foundAccount, 'update');
                    foundContact = insertContact(jsonMap, businessLine, foundAccount, foundLead, foundContact, requestBody, responseObject, response, 'update');
                }
                if (foundContact == Null || foundAccount == Null) {
                    system.debug('looking for foundcontact or foundaccount');
                    if ((Boolean) checkForContact.get('foundContact')) {
                        system.debug('found a contact?');
                        system.debug(checkForContact.get('foundContact'));
                        foundContact = (Contact) checkForContact.get('contactRecord');
                        system.debug(foundContact);

                        if ((foundContact.AccountId == '' || foundContact.AccountId == null) && foundAccount == Null) {
                            foundAccount = insertAccount(jsonMap,  businessLine, foundLead.OwnerId, foundContact, requestBody, responseObject, response, Null, 'insert');

                            foundContact = insertContact(jsonMap, businessLine, foundAccount, foundLead, foundContact, requestBody, responseObject, response, 'update');
                        } else {
                            foundAccount = insertAccount(jsonMap,  businessLine, foundLead.OwnerId, foundContact, requestBody, responseObject, response, foundAccount, 'update');

                            foundContact = insertContact(jsonMap, businessLine, foundAccount, foundLead, foundContact, requestBody, responseObject, response, 'update');
                        }
                    } else {
                        system.debug('enter else part of contact/account');
                        if (foundContact == Null && foundAccount == Null){
                            foundAccount = insertAccount(jsonMap,  businessLine, foundLead.OwnerId, foundContact, requestBody, responseObject, response, Null, 'insert');
                            foundContact = insertContact(jsonMap, businessLine, foundAccount, foundLead, foundContact, requestBody, responseObject, response, 'insert');
                        } else if (foundAccount != Null && foundAccount.Id != Null){
                            foundAccount = insertAccount(jsonMap,  businessLine, foundLead.OwnerId, foundContact, requestBody, responseObject, response, foundAccount, 'update');
                        } else {
                            foundAccount = insertAccount(jsonMap,  businessLine, foundLead.OwnerId, foundContact, requestBody, responseObject, response, Null, 'insert');
                        }

                    }
                }
                system.debug(foundContact);
                system.debug(foundAccount);

                //look for inflight oppty that is associated to the foundAccount.  If not found, the create new oppty on conversion
                list<opportunity> listinflightopps = new list<opportunity>();
                listinflightopps = [SELECT ID, Name, StageName, IsClosed, AccountId from Opportunity WHERE AccountID = :foundAccount.id AND IsClosed = FALSE limit 1];
                if (listinflightopps.size() > 0){
                    inflightopp = listinflightopps[0];
                }
                system.debug(foundContact);
                try {
                    Database.LeadConvert lc = new Database.LeadConvert();
                    lc.setLeadId(foundLead.Id);

                    LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=TRUE LIMIT 1];
                    lc.setConvertedStatus(convertStatus.MasterLabel);

                    System.debug(lc);
                    if (foundContact != null) {
                        lc.setAccountId(foundAccount.Id);
                        lc.setContactId(foundContact.Id);
                    }
                    if (inflightopp != Null && inflightopp.id != Null){
                        lc.setOpportunityId(inflightopp.id);
                    }

                    Database.LeadConvertResult lcr = Database.convertLead(lc);
                    System.assert(lcr.isSuccess());

                    Lead convertedLead = [
                            SELECT Id, Email, Company, ConvertedContactId, ConvertedAccountId, ConvertedOpportunityId
                            FROM Lead WHERE Id =: foundLead.Id LIMIT 1
                    ];
                    system.debug(convertedLead);

                    foundOpportunity = [SELECT Id, Name, StageName FROM Opportunity WHERE Id =: convertedLead.ConvertedOpportunityId LIMIT 1];

                } catch (Exception e) {
                    String subject = 'Lead Failed to Convert - Self Service';
                    String description = 'Request Body:' + requestBody + '\n'
                            + 'Error Message: ' + e.getMessage();
                    String origin = 'Web';
                    UtilityFunctions.createCase(subject, origin, description);
                    System.debug(description);
                    responseObject.responseMessage = description;
                    response.statusCode = 400;
                    restresponsetxt = JSON.serialize(responseObject);
                    response.responseBody = Blob.valueOf(JSON.serialize(responseObject));

                    Rest_Endpoint_Info__c RE = new Rest_Endpoint_Info__c();
                    RE.requestBody__c = requestbody;
                    RE.requestBody_Trimmed__c = requestbody.left(255);
                    RE.Request_URI__c = System.RestContext.request.requestURI;
                    RE.URI_Id__c = '';
                    RE.Apex_Class__c = 'SelfServiceOnboardingCreateAccount';
                    RE.Apex_Class_Method__c = 'createAccount - lead failed to convert';
                    RE.Type__c = 'Post';
                    RE.URL_Mapping__c = '/SelfService/CreateAccount/*';
                    RE.RestResponse__c = restresponsetxt.left(255);
                    insert RE;

                    return;
                }

            } else {
                System.debug(foundLead);
                foundContact = [SELECT Id, Email, FirstName, LastName, OwnerId FROM Contact WHERE Id =: foundLead.ConvertedContactId LIMIT 1];
                foundAccount = [SELECT Id,Name,Lula_Id__c FROM Account WHERE Id =: foundLead.ConvertedAccountId LIMIT 1];
                foundOpportunity = [SELECT Id, Name, StageName FROM Opportunity WHERE Id =: foundLead.ConvertedOpportunityId LIMIT 1];
            }
        } else {

            if ((Boolean) checkForContact.get('foundContact')) {
                foundContact = (Contact) checkForContact.get('contactRecord');

                List<Opportunity> contactOpps = [
                        SELECT Id, Name, Account__c, StageName, Contact__c, Business_Line__c, CreatedDate
                        FROM Opportunity
                        WHERE Contact__c =: foundContact.Id
                        ORDER BY CreatedDate DESC
                ];

                if (!contactOpps.isEmpty()) {
                    foundOpportunity = contactOpps[0];
                    foundAccount = [SELECT Id, Name FROM Account WHERE Id =: contactOpps[0].Account__c LIMIT 1];
                }
            } else {
                foundAccount = insertAccount(jsonMap,  businessLine, '', foundContact, requestBody, responseObject, response, Null, 'insert');

                foundContact = insertContact(jsonMap, businessLine, foundAccount, foundLead, foundContact, requestBody, responseObject, response, 'insert');
            }
        }

        try {

            Decimal numOfVehicles;
            if (jsonMap.numberOfVehicles == '' || jsonMap.numberOfVehicles == null) {
                numOfVehicles = null;
            } else {
                numOfVehicles = Decimal.valueOf(jsonMap.numberOfVehicles);
            }

            if (string.isnotblank(jsonMap.company)){
                if (foundOpportunity.Id != Null && foundOpportunity.Name != jsonMap.company + '-' + Date.today().format()){
                    UtilityFunctions.logApplicationMismatch('SelfServiceOnboardingCreateAccount/createAccount', 'Opportunity', 'Name', foundOpportunity.Name, 'jsonMap.company', 'Name', jsonMap.company + '-' + Date.today().format(), foundOpportunity.id, foundOpportunity.id);
                }
                foundOpportunity.Name = jsonMap.company + '-' + Date.today().format();
            } else {
                if (foundOpportunity.Id != Null && foundAccount != Null && foundOpportunity.Name != foundAccount.Name + '-' + Date.today().format()){
                    UtilityFunctions.logApplicationMismatch('SelfServiceOnboardingCreateAccount/createAccount', 'Opportunity', 'Name', foundOpportunity.Name, 'foundAccount.Name', 'Name', foundAccount.Name + '-' + Date.today().format(), foundOpportunity.id, foundAccount.id);
                }
                foundOpportunity.Name = foundAccount.Name + '-' + Date.today().format();
            }
            if (string.isnotblank(jsonMap.leadId)) foundOpportunity.Lead_Id__c = jsonMap.leadId;
            if (string.isnotblank(jsonMap.lulaId)) foundOpportunity.Lula_Id__c = jsonMap.lulaId;
            if (string.isnotblank(jsonMap.lulaId)) foundOpportunity.Firebase_Account_Id__c = jsonMap.lulaId;
            foundOpportunity.CloseDate = Date.today() + 20;
            if (string.isnotblank(businessLine)) foundOpportunity.Business_Line__c = businessLine;
            foundOpportunity.StageName = 'Discovery';
            foundOpportunity.AccountId = foundAccount.Id;
            system.debug(foundcontact);
            system.debug(foundcontact.id);
            system.debug(foundOpportunity);
            foundOpportunity.Contact__c = foundContact.Id;
            if (numOfVehicles != Null && string.valueof(numOfVehicles) != '') foundOpportunity.Number_of_Vehicles__c = numOfVehicles;
            if (string.isnotblank(productLine)) foundOpportunity.Product_Line__c = productLine;
            if (string.isnotblank(partner)) foundOpportunity.Referral_Partner_List__c = partner;
            foundOpportunity.Self_Service_Onboarding__c = true;
            foundOpportunity.RecordTypeId = recordTypeId;
            if (string.isnotblank(jsonMap.crm)) foundOpportunity.CRM__c = jsonMap.crm;
            if (string.isnotblank(jsonMap.ams)) foundOpportunity.AMS__c = jsonMap.ams;
            if (string.isnotblank(jsonMap.insuranceIndustry)) foundOpportunity.Insurance_Industry__c = jsonMap.insuranceIndustry;
            if (string.isnotblank(jsonMap.howDidYouHearAboutThisProduct)) foundOpportunity.How_Did_You_Hear_About_This_Product__c = jsonMap.howDidYouHearAboutThisProduct;
            if (string.isnotblank(jsonMap.voip)) foundOpportunity.VOIP__c = jsonMap.voip;
            if (string.isnotblank(jsonMap.quotingPlatform)) foundOpportunity.Quoting_Platform__c = jsonMap.quotingPlatform;
            if (string.isnotblank(jsonMap.addifyPrograms)) foundOpportunity.Addify_Program_s__c = jsonMap.addifyPrograms;
            if (string.isnotblank(jsonMap.vehicleRegistrationStates)) foundOpportunity.Vehicle_Registration_States__c = jsonMap.vehicleRegistrationStates;
            if (string.isnotblank(jsonMap.vehicleLotStates)) foundOpportunity.Vehicle_Lot_States__c = jsonMap.vehicleLotStates;
            foundOpportunity.OwnerId = foundLead.OwnerId;

            upsert foundOpportunity;
        } catch (Exception e) {
            String subject = 'Opportunity Failed to Create - Self Service';
            String description = 'Request Body:' + requestBody + '\n'
                    + 'Error Message: ' + e.getMessage();
            String origin = 'Web';
            UtilityFunctions.createCase(subject, origin, description);
            System.debug(description);
            responseObject.responseMessage = description;
            response.statusCode = 400;
            restresponsetxt = JSON.serialize(responseObject);
            response.responseBody = Blob.valueOf(JSON.serialize(responseObject));

            Rest_Endpoint_Info__c RE = new Rest_Endpoint_Info__c();
            RE.requestBody__c = requestbody;
            RE.requestBody_Trimmed__c = requestbody.left(255);
            RE.Request_URI__c = System.RestContext.request.requestURI;
            RE.URI_Id__c = '';
            RE.Apex_Class__c = 'SelfServiceOnboardingCreateAccount';
            RE.Apex_Class_Method__c = 'createAccount - Oppty failed to create';
            RE.Type__c = 'Post';
            RE.URL_Mapping__c = '/SelfService/CreateAccount/*';
            RE.RestResponse__c = restresponsetxt.left(255);
            insert RE;

            return;
        }


        try {
            Map<String,Object> checkForOCR = checkForOCR(foundOpportunity.Id, foundContact.Id);
            Boolean foundOCR = (Boolean) checkForOCR.get('foundOCR');
            if (!foundOCR) {
                OpportunityContactRole ocr = new OpportunityContactRole();
                ocr.OpportunityId = foundOpportunity.Id;
                ocr.ContactId = foundContact.Id;
                ocr.IsPrimary = true;

                insert ocr;
            }
        } catch (Exception e) {
            String subject = 'OCR Failed to Create - Self Service';
            String description = 'Request Body:' + requestBody + '\n'
                    + 'Error Message: ' + e.getMessage();
            String origin = 'Web';
            UtilityFunctions.createCase(subject, origin, description);
            System.debug(description);
            responseObject.responseMessage = description;
            response.statusCode = 400;
            restresponsetxt = JSON.serialize(responseObject);
            response.responseBody = Blob.valueOf(JSON.serialize(responseObject));

            Rest_Endpoint_Info__c RE = new Rest_Endpoint_Info__c();
            RE.requestBody__c = requestbody;
            RE.requestBody_Trimmed__c = requestbody.left(255);
            RE.Request_URI__c = System.RestContext.request.requestURI;
            RE.URI_Id__c = '';
            RE.Apex_Class__c = 'SelfServiceOnboardingCreateAccount';
            RE.Apex_Class_Method__c = 'createAccount - OCR failed to create';
            RE.Type__c = 'Post';
            RE.URL_Mapping__c = '/SelfService/CreateAccount/*';
            RE.RestResponse__c = restresponsetxt.left(255);
            insert RE;

            return;
        }
        system.debug(foundAccount);
        system.debug(foundAccount.id);
        system.debug(foundContact);
        system.debug(foundContact.Id);
        system.debug(foundOpportunity);
        system.debug(foundOpportunity.id);

        responseObject.accountId = foundAccount.Id;
        responseObject.opportunityId = foundOpportunity.Id;
        responseObject.contactId = foundContact.Id;

        responseObject.responseMessage = 'Account, Opportunity, Contact successfully created. Lead successfully converted.';
        response.statusCode = 200;
        restresponsetxt = JSON.serialize(responseObject);
        response.responseBody = Blob.valueOf(JSON.serialize(responseObject));

        Rest_Endpoint_Info__c RE = new Rest_Endpoint_Info__c();
        RE.requestBody__c = requestbody;
        RE.requestBody_Trimmed__c = requestbody.left(255);
        RE.Request_URI__c = System.RestContext.request.requestURI;
        RE.URI_Id__c = '';
        RE.Apex_Class__c = 'SelfServiceOnboardingCreateAccount';
        RE.Apex_Class_Method__c = 'createAccount';
        RE.Type__c = 'Post';
        RE.URL_Mapping__c = '/SelfService/CreateAccount/*';
        RE.RestResponse__c = restresponsetxt.left(255);
        insert RE;
    }
}
