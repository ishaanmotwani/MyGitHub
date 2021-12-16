/****************************************************************************************************
Class Name      : RHM_RecordHistoryManager
Description     : This class creates record history records when a record is created/updated/deleted
Created By      : Deloitte
Created Date    : August 27, 2021
Modification Log:
-----------------------------------------------------------------------------------------------------
Developer                   Date                        Description
-----------------------------------------------------------------------------------------------------
Betson                August 27, 2021                 Initial Version
*****************************************************************************************************/
public class RHM_RecordHistoryManager implements Queueable {
    public static final String CLASSNAME = 'RHM_RecordHistoryManager';
    
    private static final String[] EXCLUDED_FIELDS = new String[]{'lastmodifiedbyid','lastmodifieddate','lastvieweddate','systemmodstamp'};
        
        private static final String RECORD_INSERT_VALUE ='Record Inserted';
    private static final String RECORD_DELETE_VALUE ='Record Deleted';
    private static final String RECORD_UNDELETE_VALUE ='Record Undeleted';
    
    private static final Id RECORDTYPEID_INSERT = RHM_Utility.getRecordTypeId(RHM_Constants.RECORD_HISTORY_API_NAME, RHM_Constants.RECORD_TYPE_RECORD_HISTORY_INSERT);
    private static final Id RECORDTYPEID_UPDATE = RHM_Utility.getRecordTypeId(RHM_Constants.RECORD_HISTORY_API_NAME, RHM_Constants.RECORD_TYPE_RECORD_HISTORY_UPDATE);
    private static final Id RECORDTYPEID_DELETE = RHM_Utility.getRecordTypeId(RHM_Constants.RECORD_HISTORY_API_NAME, RHM_Constants.RECORD_TYPE_RECORD_HISTORY_DELETE);
    private static final Id RECORDTYPEID_UNDELETE = RHM_Utility.getRecordTypeId(RHM_Constants.RECORD_HISTORY_API_NAME, RHM_Constants.RECORD_TYPE_RECORD_HISTORY_UNDELETE);
    
    private static final String CUSTOMOBJECT_NAME_REGEX = '(SOC|PatientConnect__PC)_(.*)__c';
    
    private Map<Id,SObject> oldMap,newMap;
    private DescribeSObjectResult objectInfo;
    private String ObjectLookupFieldApiName='';
    private TriggerOperation operationType;
    
    public RHM_RecordHistoryManager( System.TriggerOperation operationType,Map<Id,SObject> oldMap,Map<Id,SObject> newMap){
        this.oldMap = oldMap;
        this.newMap = newMap;
        this.operationType = operationType;
    }
    
    /**
Method Name    : execute 
Description    : method that initiates Record History record creation.
**/  
    public void execute(System.QueueableContext qc) {
        try{ 
            initialize(newMap != null ? newMap.values().get(0) : oldMap.values().get(0));
            insertRecordHistoryRecords();
            
        }catch(Exception e){
            //RHM_Utility.createErrorLog(e,CLASSNAME,'RHM_RecordHistoryManager');
			//Add your exception handling methods here
            throw e;
        }
    }
    /**
Method Name    : initialize 
Description    : fetches all necessary details.
**/  
    private void initialize(SObject record){
        objectInfo = record.getSObjectType().getDescribe(); 
        if(objectInfo.isCustom()){
            Matcher matcher = Pattern.compile(CUSTOMOBJECT_NAME_REGEX).matcher(objectInfo.getName());
            if(matcher.matches()){
                ObjectLookupFieldApiName = matcher.group(2);
            }      
        }else{
            ObjectLookupFieldApiName = objectInfo.getName();
        }
        ObjectLookupFieldApiName= 'RHM_'+ObjectLookupFieldApiName+'__c';
        if(!RHM_Record_History__c.getSObjectType().getDescribe().fields.getMap().containsKey(ObjectLookupFieldApiName)){
            ObjectLookupFieldApiName='';
        }  
    }
    
    /**
Method Name    : insertRecordHistoryRecords 
Description    : inserts Record History records.
**/  
    private void insertRecordHistoryRecords(){
        List<RHM_Record_History__c> recordHistoryList = new List<RHM_Record_History__c>();
        Map<String,Schema.SObjectField> fieldMap = objectInfo.fields.getMap();
        Set<Id> recordIds = (newMap != null && !newMap.isEmpty()) ? newMap.keySet() : oldMap.keySet();
        for(Id recordId : recordIds){
            
            SObject oldRecord = oldMap != null ? oldMap.get(recordId) : null;
            SObject newRecord = newMap != null ? newMap.get(recordId) : null;
            
            switch on operationType {
                when AFTER_INSERT {
                    RHM_Record_History__c historyRecord = createRecordHistoryRecord(recordId);
                    historyRecord = updateRecordForInsertOperation(historyRecord,newRecord);
                    recordHistoryList.add(historyRecord);
                }
                when AFTER_UPDATE {
                    for(String fieldName : fieldMap.keyset()){
                        DescribeFieldResult fieldInfo = fieldMap.get(fieldName).getDescribe();
                        if(!EXCLUDED_FIELDS.contains(fieldName) && !fieldInfo.isCalculated()  && oldRecord.get(fieldName) != newRecord.get(fieldName)){
                            RHM_Record_History__c historyRecord = createRecordHistoryRecord(recordId);
                            historyRecord = updateRecordForUpdateOperation(historyRecord,newRecord,fieldInfo,oldRecord.get(fieldName));
                            recordHistoryList.add(historyRecord);
                        }
                    }  
                }
                when AFTER_DELETE {
                    RHM_Record_History__c historyRecord = createRecordHistoryRecord(recordId);
                    historyRecord = updateRecordForDeleteOperation(historyRecord);
                    recordHistoryList.add(historyRecord);
                }
                when AFTER_UNDELETE {
                    RHM_Record_History__c historyRecord = createRecordHistoryRecord(recordId);
                    historyRecord = updateRecordForUndeleteOperation(historyRecord);
                    recordHistoryList.add(historyRecord);   
                }
            }
            
            
        }
        if(!recordHistoryList.isEmpty())
            insert recordHistoryList; 
    }
    
    /**
Method Name    : createRecordHistoryRecord 
Description    : creates Record History record.
**/  
    private RHM_Record_History__c createRecordHistoryRecord(String recordId){
        RHM_Record_History__c historyRecord = new RHM_Record_History__c(
            RHM_Object_Name__c = objectInfo.getLabel(),
            RHM_Object_API_Name__c = objectInfo.getName(),
            RHM_Modified_By__c = (Id)UserInfo.getUserId(),
            RHM_Record_Id__c = recordId,
            RHM_Modified_On__c = System.now()
        );
        
        if(String.isNotBlank(ObjectLookupFieldApiName)){
            historyRecord.put(ObjectLookupFieldApiName,historyRecord.RHM_Record_Id__c);  
        }
        
        return historyRecord;
    }
    
    /**
Method Name    : updateRecordForInsertOperation 
Description    : updates Record History record for insert operation.
**/ 
    private RHM_Record_History__c updateRecordForInsertOperation(RHM_Record_History__c historyRecord,SObject record){
        historyRecord.RecordTypeId = RECORDTYPEID_INSERT;
        historyRecord.RHM_Modified_On__c = (DateTime)record.get('lastmodifieddate');
        historyRecord.RHM_New_Value__c = RECORD_INSERT_VALUE;
        return historyRecord;
    }
    
    /**
Method Name    : updateRecordForUpdateOperation 
Description    : updates Record History record for update operation.
**/ 
    private RHM_Record_History__c updateRecordForUpdateOperation(RHM_Record_History__c historyRecord,SObject record,DescribeFieldResult fieldInfo,Object oldValue){
        historyRecord.RecordTypeId = RECORDTYPEID_UPDATE;
        historyRecord.RHM_Modified_On__c = (DateTime)record.get('lastmodifieddate');
        
        historyRecord.RHM_Field_Name__c = fieldInfo.getLabel();
        historyRecord.RHM_Field_API_Name__c =fieldInfo.getName();
        
        historyRecord.RHM_Old_Value__c =String.valueOf(oldValue);
        historyRecord.RHM_New_Value__c = String.valueOf(record.get(fieldInfo.getName())); 
        
        for( Schema.PicklistEntry pickListVal : fieldInfo.getPicklistValues()){
            if(pickListVal.getValue()==historyRecord.RHM_New_Value__c){
                historyRecord.RHM_Picklist_Value_API_Name__c=historyRecord.RHM_New_Value__c;
                historyRecord.RHM_New_Value__c =pickListVal.getLabel();
            }
        }
        if(fieldInfo.getType() == Schema.DisplayType.DATETIME){
            historyRecord.RHM_Old_Value_Date_Time__c =(DateTime)oldValue;
            historyRecord.RHM_New_Value_Date_Time__c = (DateTime)record.get(fieldInfo.getName()); 
        }
        if(fieldInfo.getType() == Schema.DisplayType.DATE){
            historyRecord.RHM_Old_Value_Date_Time__c = (Date)oldValue;
            historyRecord.RHM_New_Value_Date_Time__c =(Date)record.get(fieldInfo.getName());
        }
        if(fieldInfo.getType() == Schema.DisplayType.TIME){
            //historyRecord.RHM_Old_Value_Date_Time__c = (Time)oldValue;
            //historyRecord.RHM_New_Value_Date_Time__c =  (Time)record.get(fieldInfo.getName()); 
        }
        
        return historyRecord;
    }
    
    /**
Method Name    : updateRecordForDeleteOperation 
Description    : updates Record History record for delete operation.
**/ 
    private RHM_Record_History__c updateRecordForDeleteOperation(RHM_Record_History__c historyRecord){
        historyRecord.RecordTypeId = RECORDTYPEID_DELETE;
        historyRecord.RHM_New_Value__c = RECORD_DELETE_VALUE;
        
        if(String.isNotBlank(ObjectLookupFieldApiName)){
            historyRecord.put(ObjectLookupFieldApiName,null);  
        }
        return historyRecord;
    }
    
    /**
Method Name    : updateRecordForUndeleteOperation 
Description    : updates Record History record for undelete operation.
**/ 
    private RHM_Record_History__c updateRecordForUndeleteOperation(RHM_Record_History__c historyRecord){
        historyRecord.RecordTypeId = RECORDTYPEID_UNDELETE;
        historyRecord.RHM_New_Value__c = RECORD_UNDELETE_VALUE;
        
        return historyRecord;
    }
}