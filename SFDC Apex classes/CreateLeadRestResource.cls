/**
 * Updated by Rick Nash on 06252025.
 */

@RestResource(urlMapping='/SelfService/CreateLead/*')
global with sharing class CreateLeadRestResource {

    public class leadRequest {
        public String coverageType;
        public String firstName;
        public String lastName;
        public String company;
        public String phone;
        public String email;
        public String leadSource;
        public String referralPartner;
        public String leadSourceDetail;
        public String utmSource;
        public String utmMedium;
        public String utmCampaign;
        public String utmContent;
        public String utmTerm;
        public String growsurfParticipantId;
        public String crm;
        public String ams;
        public String insuranceIndustry;
        public String howDidYouHearAboutThisProduct;
        public String voip;
        public String quotingPlatform;
        public integer fleetSize;
    }

    private static Map<String,Object> checkForLead(leadRequest onboardingMap) {

        Map<String,Object> responseMap = new Map<String,Object>();

        List<Lead> searchLead = [
                SELECT Id, Email, Company, Status, OwnerId, LeadSource, Business_Line__c FROM Lead
                WHERE IsConverted = FALSE AND Email =: onboardingMap.email LIMIT 1];

        if (!searchLead.isEmpty()) {
            responseMap.put('foundLead', true);
            responseMap.put('leadRecord', searchLead[0]);
        } else {
            responseMap.put('foundLead', false);
        }

        return responseMap;
    }

    @HttpPost
    global static void createLead() {

        RestResponse response = RestContext.response;
        String requestBody = System.RestContext.request.requestBody.toString();
        leadRequest requestData = (leadRequest) JSON.deserialize(requestBody, leadRequest.class);
        system.debug(requestData);
        system.debug(requestData.email);
        //query for lead
        List<Lead> unconvertedLeads = [
                SELECT Id, Email, Company, Status, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId, OwnerId, IsConverted, LeadSource, Business_Line__c FROM Lead
                WHERE Email =: requestData.email AND Email != '' AND IsConverted = FALSE
                ORDER BY CreatedDate DESC LIMIT 1];
        List<Lead> convertedLeads = [
                SELECT Id, Email, Company, Status, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId, OwnerId, IsConverted, LeadSource, Business_Line__c FROM Lead
                WHERE Email =: requestData.email AND Email != '' AND IsConverted = TRUE
                ORDER BY CreatedDate DESC LIMIT 1];
        system.debug(unconvertedLeads.size());
        lead convertedlead = new lead();
        lead inflightlead = new lead();
        lead foundLead = new lead();
        lead leadtocreate = new lead();
        contact foundContact = new contact();
        account foundAccount = new account();
        opportunity foundOpportunity = new opportunity();
        string leadSource = '';
        String businessLine = '';
        String productLine = '';
        String recordTypeId;
        boolean noleadfound = false;
        if (unconvertedLeads.isEmpty() && convertedLeads.isEmpty()){
            noleadfound = true;
        } else {
            if (!unconvertedLeads.isEmpty()) inflightlead = unconvertedLeads[0];
            if (!convertedLeads.isEmpty()) convertedLead = convertedLeads[0];
        }
        system.debug(inflightlead.id);
        system.debug(noleadfound);
        if ((inflightlead != Null && inflightlead.id != Null) || noleadfound == true){
            //there is an open lead, update it, or there is no matching lead found, create new
            if (inflightlead != Null){
                foundLead = inflightlead;
                leadToCreate.Id = foundLead.Id;
                leadToCreate.OwnerId = foundLead.OwnerId;
                if (foundLead.LeadSource != null && foundLead.LeadSource != '') {
                   leadSource = foundLead.LeadSource;
                }
            }
            if (requestData.leadSource != null && requestData.leadSource != '') {
                leadSource = requestData.leadSource;
            }


            String partner = requestData.referralPartner;
            if (requestData.coverageType != '') {
                switch on requestData.coverageType {
                    when 'Continuous_Coverage' {
                        RecordType leadRecordType = [
                                SELECT Id FROM RecordType
                                WHERE Name = 'Commercial Auto'
                                AND SobjectType = 'Lead' LIMIT 1
                        ];
                        businessLine = 'Commercial Auto';
                        productLine = 'Private Rental';
                        recordTypeId = leadRecordType.Id;
                    }
                    when 'Continuous_Coverage_GBA' {
                        RecordType leadRecordType = [
                                SELECT Id FROM RecordType
                                WHERE Name = 'Commercial Auto'
                                AND SobjectType = 'Lead' LIMIT 1
                        ];
                        businessLine = 'Commercial Auto';
                        partner = 'GBA';
                        leadSource = 'Partner';
                        productLine = 'Private Rental';
                        recordTypeId = leadRecordType.Id;
                    }
                    when 'ORP' {
                        RecordType leadRecordType = [
                                SELECT Id FROM RecordType
                                WHERE Name = 'Commercial Auto'
                                AND SobjectType = 'Lead' LIMIT 1
                        ];
                        businessLine = 'Commercial Auto';
                        productLine = 'ORP';
                        recordTypeId = leadRecordType.Id;
                    }
                    when 'GAIL' {
                        RecordType leadRecordType = [
                                SELECT Id FROM RecordType
                                WHERE Name = 'AI'
                                AND SobjectType = 'Lead' LIMIT 1
                        ];
                        Group AI_Assignment_Queue = [
                                SELECT Id FROM Group
                                WHERE Type = 'Queue' AND Name = 'AI Lead Assign'
                                LIMIT 1
                        ];
                        businessLine = 'AI';
                        productLine = 'GAIL';
                        recordTypeId = leadRecordType.Id;
                        //leadToCreate.OwnerId = AI_Assignment_Queue.Id;
                    }
                    when else {
                        RecordType leadRecordType = [
                                SELECT Id FROM RecordType
                                WHERE Name = 'Commercial Auto'
                                AND SobjectType = 'Lead' LIMIT 1
                        ];
                        businessLine = 'Commercial Auto';
                        recordTypeId = leadRecordType.Id;
                    }
                }
            }

            if (string.isnotblank(requestData.firstName)) leadToCreate.FirstName = requestData.firstName;
            if (string.isnotblank(requestData.lastName)) leadToCreate.LastName = requestData.lastName;
            if (string.isnotblank(requestData.company)) leadToCreate.Company = requestData.company;
            if (requestData.fleetSize != null) leadToCreate.Number_of_Vehicles__c = requestData.fleetSize;
            if (string.isnotblank(businessLine)) leadToCreate.Business_Line__c = businessLine;
            if (string.isnotblank(productLine)) leadToCreate.Product_Line__c = productLine;
            leadToCreate.LeadSource = (leadSource != null ? leadSource : 'Direct Traffic');
            leadToCreate.Self_Service_Onboarding__c = true;
            if (string.isnotblank(requestData.referralPartner)) leadToCreate.Referral_Partner_List__c = requestData.referralPartner;
            if (string.isnotblank(requestData.leadSourceDetail)) leadToCreate.Lead_Source_Detail__c = requestData.leadSourceDetail;
            if (string.isnotblank(requestData.utmSource)) leadToCreate.UTM_Source__c = requestData.utmSource;
            if (string.isnotblank(requestData.utmMedium)) leadToCreate.UTM_Medium__c = requestData.utmMedium;
            if (string.isnotblank(requestData.utmCampaign)) leadToCreate.UTM_Campaign__c = requestData.utmCampaign;
            if (string.isnotblank(requestData.utmContent)) leadToCreate.UTM_Content__c = requestData.utmContent;
            if (string.isnotblank(requestData.utmTerm)) leadToCreate.UTM_Term__c = requestData.utmTerm;
            if (string.isnotblank(requestData.growsurfParticipantId)) leadToCreate.GrowSurf_Participant_Id__c = requestData.growsurfParticipantId;
            if (requestData.phone != null && requestData.phone != '') {
                leadToCreate.Phone = requestData.phone;
            }
            if (requestData.email != Null && requestData.email != '') {
                if (leadToCreate.Id != Null && string.isnotblank(leadToCreate.Email) && leadToCreate.Email != requestData.email){
                    UtilityFunctions.logApplicationMismatch('CreateLeadRestResource/createLead', 'Lead', 'Email', leadToCreate.Email, 'Lead', 'Email', requestData.email, leadToCreate.Id, leadToCreate.id);
                }
                leadToCreate.Email = requestData.email;
            }
            if (string.isnotblank(requestData.crm)) leadToCreate.CRM__c = requestData.crm;
            if (string.isnotblank(requestData.ams)) leadToCreate.AMS__c = requestData.ams;
            if (string.isnotblank(requestData.insuranceIndustry)) leadToCreate.Insurance_Industry__c = requestData.insuranceIndustry;
            if (string.isnotblank(requestData.howDidYouHearAboutThisProduct)) leadToCreate.How_Did_You_Hear_About_This_Product__c = requestData.howDidYouHearAboutThisProduct;
            if (string.isnotblank(requestData.voip)) leadToCreate.VOIP__c = requestData.voip;
            if (string.isnotblank(requestData.quotingPlatform)) leadToCreate.Quoting_Platform__c = requestData.quotingPlatform;
            leadToCreate.RecordTypeId = recordTypeId;

            if (leadToCreate.OwnerId == Null){
                leadToCreate.OwnerId = UserInfo.GetUserId();
            }
            System.debug(leadToCreate);
            System.debug(leadToCreate.id);


            try {
                upsert leadToCreate;
                system.debug(leadToCreate.id);
                response.statusCode = 200;
                response.responseBody = Blob.valueOf('{"leadId":"' + leadToCreate.Id + '"}');
            } catch(Exception e) {
                System.debug(e.getMessage());
                String subject = 'Lead Failed to Create - Self Service';
                String description = 'Request Body: ' + requestBody + '\n' + 'Error Message: ' + e.getMessage();
                String origin = 'Web';
                UtilityFunctions.createCase(subject, origin, description);

                response.statusCode = 400;
                response.responseBody = Blob.valueOf('{"errorMessage":"Lead failed to create, ' + e.getMessage() + '"}');
            }

        } else if (convertedLead.id != Null) {
            //only converted lead - get account, contact and oppty and update
            system.debug('found converted lead');
            if (convertedLead.ConvertedContactId != Null){
                foundContact = [SELECT ID, Name, Email, FirstName, LastName, AccountID from Contact WHERE ID = :convertedLead.ConvertedContactId];
            }
            if(convertedLead.ConvertedAccountId != Null){
                foundAccount = [SELECT ID, Name from Account WHERE ID = :convertedLead.ConvertedAccountId];
            }
            if (convertedLead.ConvertedOpportunityId != Null){
                foundOpportunity = [SELECT ID, Name, StageName, IsClosed from Opportunity WHERE ID = :convertedLead.ConvertedOpportunityId];
            }
            if (requestData.coverageType != '') {
                switch on requestData.coverageType {
                    when 'Continuous_Coverage' {
                        businessLine = 'Commercial Auto';
                        productLine = 'Private Rental';
                    }
                    when 'Continuous_Coverage_GBA' {
                        businessLine = 'Commercial Auto';
                        leadSource = 'Partner';
                        productLine = 'Private Rental';
                    }
                    when 'ORP' {
                        businessLine = 'Commercial Auto';
                        productLine = 'ORP';
                    }
                    when 'GAIL' {
                        businessLine = 'AI';
                        productLine = 'GAIL';
                    }
                    when else {
                        businessLine = 'Commercial Auto';
                    }
                }
            }

            system.debug(foundContact);
            system.debug(foundAccount);
            system.debug(foundOpportunity);
            if (foundContact != Null && foundContact.id != Null){
                if (string.isnotblank(requestData.firstName)) foundContact.FirstName = requestData.firstName;
                if (string.isnotblank(requestData.lastName)) foundContact.LastName = requestData.lastName;
                if (string.isnotblank(requestData.leadSourceDetail)) foundContact.Lead_Source_Detail__c = requestData.leadSourceDetail;
                foundContact.LeadSource = (leadsource != Null && string.isnotblank(leadSource) ? leadSource : 'Direct Traffic');
                if (string.isnotblank(requestData.growsurfParticipantId)) foundContact.GrowSurf_Participant_Id__c = requestData.growsurfParticipantId;
                if (requestData.phone != Null && requestData.phone != '') {
                    foundContact.Phone = requestData.phone;
                }
                if (requestData.email != Null && requestData.email != '') {
                    if (foundContact.Id != Null && string.isnotblank(foundContact.Email) && foundContact.Email != requestData.email){
                        UtilityFunctions.logApplicationMismatch('CreateLeadRestResource/createLead', 'Contact', 'Email', foundContact.Email, 'Contact', 'Email', requestData.email, foundContact.Id, foundContact.id);
                    }
                    foundContact.Email = requestData.email;
                }
            }
            if (foundAccount != Null && foundAccount.id != Null){
                if (string.isnotblank(requestData.company) && foundAccount.Id != Null && string.isnotblank(foundAccount.Name) && foundAccount.Name.tolowercase().trim() != requestData.company.tolowercase().trim()){
                        UtilityFunctions.logApplicationMismatch('CreateLeadRestResource/createLead', 'Account', 'Name', foundAccount.Name, 'Account', 'Name', requestData.company, foundAccount.Id, foundAccount.id);
                }
                if (string.isnotblank(requestData.company)) foundAccount.Name = requestData.company;
                if (string.isnotblank(businessLine)) foundAccount.Business_Line__c = businessLine;
                if (string.isnotblank(productLine)) foundAccount.LULA_Product_Line__c = productLine;
                if (string.isnotblank(requestData.voip)) foundAccount.VOIP__c = requestData.voip;
            }
            if (foundOpportunity != Null && foundOpportunity.id != Null && foundOpportunity.IsClosed == FALSE){
                if (string.isnotblank(businessLine)) foundOpportunity.Business_Line__c = businessLine;
                if (string.isnotblank(productLine)) foundOpportunity.Product_Line__c = productLine;
                foundOpportunity.LeadSource = (leadsource != Null && string.isnotblank(leadSource) ? leadSource : 'Direct Traffic');
                foundOpportunity.Self_Service_Onboarding__c = true;
                if (string.isnotblank(requestData.referralPartner)) foundOpportunity.Referral_Partner_List__c = requestData.referralPartner;
                if (string.isnotblank(requestData.leadSourceDetail)) foundOpportunity.Lead_Source_Detail__c = requestData.leadSourceDetail;
                if (string.isnotblank(requestData.utmSource)) foundOpportunity.UTM_Source__c = requestData.utmSource;
                if (string.isnotblank(requestData.utmMedium)) foundOpportunity.UTM_Medium__c = requestData.utmMedium;
                if (string.isnotblank(requestData.utmCampaign)) foundOpportunity.UTM_Campaign__c = requestData.utmCampaign;
                if (string.isnotblank(requestData.utmContent)) foundOpportunity.UTM_Content__c = requestData.utmContent;
                if (string.isnotblank(requestData.utmTerm)) foundOpportunity.UTM_Term__c = requestData.utmTerm;
                if (string.isnotblank(requestData.crm)) foundOpportunity.CRM__c = requestData.crm;
                if (string.isnotblank(requestData.ams)) foundOpportunity.AMS__c = requestData.ams;
                if (string.isnotblank(requestData.insuranceIndustry)) foundOpportunity.Insurance_Industry__c = requestData.insuranceIndustry;
                if (string.isnotblank(requestData.howDidYouHearAboutThisProduct)) foundOpportunity.How_Did_You_Hear_About_This_Product__c = requestData.howDidYouHearAboutThisProduct;
                if (string.isnotblank(requestData.voip)) foundOpportunity.VOIP__c = requestData.voip;
                if (string.isnotblank(requestData.quotingPlatform)) foundOpportunity.Quoting_Platform__c = requestData.quotingPlatform;
            }
            if (foundContact != Null && foundContact.id != Null){
                try {
                    update foundContact;
                } catch(Exception e) {
                    System.debug(e.getMessage());
                    String subject = 'CreateLeadRestResource - foundContact (' + string.valueof(foundContact.id) + ') failed to update.';
                    String description = 'Request Body: ' + requestBody + '\n' + 'Error Message: ' + e.getMessage();
                    String origin = 'Web';
                    UtilityFunctions.createCase(subject, origin, description);
                }
            }
            if (foundAccount != Null && foundAccount.id != Null){
                try {
                    update foundAccount;
                } catch(Exception e) {
                    System.debug(e.getMessage());
                    String subject = 'CreateLeadRestResource - foundAccount (' + string.valueof(foundAccount.id) + ') failed to update.';
                    String description = 'Request Body: ' + requestBody + '\n' + 'Error Message: ' + e.getMessage();
                    String origin = 'Web';
                    UtilityFunctions.createCase(subject, origin, description);
                }
            }
            if (foundOpportunity != Null && foundOpportunity.id != Null  && foundOpportunity.IsClosed == FALSE){
                try {
                    update foundOpportunity;
                } catch(Exception e) {
                    System.debug(e.getMessage());
                    String subject = 'CreateLeadRestResource - foundOpportunity (' + string.valueof(foundOpportunity.id) + ') failed to update.';
                    String description = 'Request Body: ' + requestBody + '\n' + 'Error Message: ' + e.getMessage();
                    String origin = 'Web';
                    UtilityFunctions.createCase(subject, origin, description);
                }
            }
       }

        Rest_Endpoint_Info__c RE = new Rest_Endpoint_Info__c();
        RE.requestBody__c = requestBody;
        RE.requestBody_Trimmed__c = requestBody.left(255);
        RE.Request_URI__c = System.RestContext.request.requestURI;
        RE.URI_Id__c = '';
        RE.Apex_Class__c = 'CreateLeadRestResource';
        RE.Apex_Class_Method__c = 'createLead';
        RE.Type__c = 'Post';
        RE.URL_Mapping__c = '/SelfService/CreateLead/*';
        if (response != Null && response.responseBody != Null) RE.RestResponse__c = string.valueof(response.responseBody.tostring()).left(255);
        insert RE;
    }
}
