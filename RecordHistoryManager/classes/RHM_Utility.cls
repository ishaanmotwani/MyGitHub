/*********************************************************************************
Class Name      : RHM_Utility 
Description     : This class will contain generic methods that will be used across the Application.
Created By      : Deloitte               
Created Date    : April 20, 2020
Modification Log:
---------------------------------------------------------------------------------- 
Developer                      Date                        Description
----------------------------------------------------------------------------------            
Shivam Joshi                   April 20, 2020              Initial Version
Bhavesh Dhirwani               June 25, 2020               Added getFieldsFromFieldSet method
*********************************************************************************/
public class RHM_Utility {
    
    private static Map<String, Id> sRecordTypeMap = new Map<String, Id>();
    public static final string CLASSNAME='RHM_Utility';
    

    /*********************************************************************************
Method Name    : getRecordTypeId 
Description    : Method to return Record Type ID
Parameter      : 1. pObjName : Object Name
2. pDeveloperName : Developer Name of Record Type         
*********************************************************************************/
    public static Id getRecordTypeId(String pObjName, String pDeveloperName){
        try{
            Id recTypeId = sRecordTypeMap.get(pObjName + pDeveloperName);
            if(recTypeId != null){
                return recTypeId;
            }
            recTypeId = Schema.getGlobalDescribe().get(pObjName).getDescribe().getRecordTypeInfosByDeveloperName().get(pDeveloperName).getRecordTypeId(); 
            sRecordTypeMap.put(pObjName + pDeveloperName,recTypeId);   
            return recTypeId;
        }
        Catch(Exception e){
            return null;
        }
    }

}