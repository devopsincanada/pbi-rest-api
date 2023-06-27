# Getting Refresh History for Power BI Datasets

## Introduction

Use the Power BI REST APIs to get refresh history for all datasets across all workspaces, store the results in JSON and CSV files, and copy these files to Azure Blob Storage. Automate this entire process using an Azure DevOps pipeline that runs on a schedule.

## Outline

1. [Create a service principal in Azure Active Directory](#create-a-service-principal-in-azure-active-directory)
1. [Create a security group in Azure Active Directory](#create-a-security-group-in-azure-active-directory)
1. [Grant the security group access to Power BI](#grant-the-security-group-access-to-power-bi)
1. [Create an Azure DevOps organization](#create-an-azure-devops-organization)
1. [Create an Azure DevOps project](#create-an-azure-devops-project)
1. [Create an Azure DevOps service connection](#create-an-azure-devops-service-connection)
1. [Create an Azure Storage account](#create-an-azure-storage-account)
1. [Create an Azure Storage container](#create-an-azure-storage-container)
1. [Give the Azure DevOps service connection access to the storage account](#give-the-azure-devops-service-connection-access-to-the-storage-account)
1. [Create an Azure DevOps pipeline variable group](#create-an-azure-devops-pipeline-variable-group)
1. [Create an Azure DevOps git repository](#create-an-azure-devops-git-repository)
1. [Create an Azure DevOps pipeline](#create-an-azure-devops-pipeline)

## Detailed Steps

### Create a service principal in Azure Active Directory

This service principal will be used by the `Get-RefreshHistory.ps1` script to authenticate with the Power BI REST APIs.

1. In the Azure portal, navigate to `Azure Active Directory > App registrations > New registration`
2. Enter a name for the app registration
3. Select 'Accounts in this organizational directory only' as the supported account types
4. Leave the redirect URI empty
5. Click 'Register'
6. Copy the 'Application (client) ID' and save it for later as the `AppId`
7. Click `Certificates & secrets > New client secret`
8. Enter a description for the client secret
9. Select an expiration date
10. Click 'Add'
11. Copy the client secret value and save it for later as the `AppSecret`
12. Click 'API permissions'
13. Remove the default 'Microsoft Graph' permission(s)

### Create a security group in Azure Active Directory

This security group will be used to grant the service principal access to all workspaces in the Power BI tenant.

1. In the Azure portal, navigate to `Azure Active Directory > Groups > New group`
2. Enter a name for the group
3. Select 'Security' as the group type
4. Set the membership type to 'Assigned'
5. Set 'Azure AD roles can be assigned to the group' to 'Yes'
6. Click 'No members selected'
7. Select the service principal that was created in the previous step
8. Click 'Select'
9. Click 'Create'

### Grant the security group access to Power BI

This will allow the service principal to get refresh history for all datasets across all workspaces.

1. Navigate to the [Power BI Admin Portal](https://app.powerbi.com/admin-portal/home)
2. Click 'Tenant settings'
3. Scroll to the 'Developer settings' section
4. Set 'Allow service principals to use Power BI APIs' to 'Enabled'
5. Set 'Specific security groups' to the security group that was created in the previous step
6. Click 'Apply'
7. Scroll to the 'Admin API settings' section
8. Set 'Allow service principals to use read-only admin APIs' to 'Enabled'
9. Set 'Specific security groups' to the security group that was created in the previous step
10. Click 'Apply'
11. Click on 'Workspaces'
12. For each workspace, click on the 'Access' tab, and add the security group created in the previous step as an admin
13. Navigate to the [Microsoft 365 admin center](https://admin.microsoft.com/Adminportal/Home)
14. Click on 'Roles > Role assignments > Fabric Administrator > Assigned > Add groups'
15. Select the security group created in the previous step
16. Click 'Add'

### Create an Azure DevOps organization

This organization will contain the project that stores the Git code repository and pipeline.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts, or if you already have an existing Azure DevOps organization that you want to use.

1. In the Azure DevOps portal, navigate to `Organizations > New organization`
2. Enter a name for the organization
3. Enter the captcha
4. Click 'Continue'

### Create an Azure DevOps project

This project will contain the Git code repository and pipeline that runs on a schedule to get refresh history for all datasets across all workspaces, store the results in JSON and CSV files, and copy these files to Azure Blob Storage.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts, or if you already have an existing Azure DevOps project that you want to use.

1. In the Azure DevOps portal, navigate to `Projects > New project`
2. Enter a name for the project
3. Select 'Private' as the visibility
4. Select 'Git' as the version control
5. Select 'Agile' as the work item process
6. Click 'Create'

### Create an Azure DevOps service connection

This service connection will be used by the pipeline to authenticate with Azure Resource Manager and copy the JSON and CSV files to Azure Blob Storage. The service connection will be created using a service principal that is automatically generated by Azure DevOps.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts, or if you already have an existing Azure DevOps service connection that you want to use.

1. In the Azure DevOps portal, navigate to `Project settings > Service connections > New service connection > Azure Resource Manager`
2. Select 'Service principal (automatic)'
3. Select the Azure subscription containing the storage account
4. Select the resource group containing the storage account
5. Enter a name for the service connection and save it for later as the `ServiceConnection`
6. Click 'Save'

### Create an Azure Storage account

This storage account will be used to store the JSON and CSV files that contain the refresh history for all datasets across all workspaces.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts, or if you already have an existing Azure Storage account that you want to use.

1. In the Azure portal, navigate to `Storage accounts > Add`
2. Enter a name for the storage account and save it for later as the `StorageAccount`
3. Select the Azure subscription containing the storage account
4. Select the resource group containing the storage account
5. Select the location of the storage account
6. Select 'StorageV2 (general purpose v2)' as the account kind
7. Select 'Hot' as the performance
8. Select 'LRS' as the replication
9. Click 'Review + create'
10. Click 'Create'

### Create an Azure Storage container

This storage container will be used to store the JSON and CSV files that contain the refresh history for all datasets across all workspaces.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts, or if you already have an existing Azure Storage container that you want to use.

1. In the Azure portal, navigate to `Storage accounts > Select storage account > Containers > + Container`
2. Enter a name for the container and save it for later as the `StorageContainer`
3. Select 'Blob' as the public access level
4. Click 'OK'

### Give the Azure DevOps service connection access to the storage account

This will allow the pipeline to copy the JSON and CSV files to Azure Blob Storage.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts.

1. In the Azure portal, navigate to `Storage accounts > Select storage account > Access control (IAM) > Add > Add role assignment`
2. Select the role 'Storage Blob Data Owner'
3. Select the service principal generated when you created the service connection (it will be in the format `<AzDevOpsOrgName>-<AzDevOpsProjectName>-<GUID>`)
4. Click 'Next'
5. Click 'Review + create'

### Create an Azure DevOps pipeline variable group

This variable group will contain the variables that are used by the pipeline.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts.

1. In the Azure DevOps portal, navigate to `Pipelines > Library > Variable groups > + Variable group`
2. Enter the name `pbi-rest-api-variables` for the variable group
3. Add the following variables and their values to the variable group:
   - `TenantId` - The Azure Active Directory tenant ID
   - `AppId` - The application ID of the service principal
   - `AppSecret` - The client secret of the service principal (click the lock icon to encrypt the value)
   - `ServiceConnection` - The name of the Azure Resource Manager service connection
   - `StorageAccount` - The name of the Azure Storage account
   - `StorageContainer` - The name of the Azure Storage container

### Create an Azure DevOps git repository

This repository will contain the PowerShell script `Get-RefreshHistory.ps1` and YAML pipeline definition `pbi-rest-api.yml` files.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts, or if you already have an existing Azure DevOps git repository that you want to use.

1. In the Azure DevOps portal, navigate to `Repos > Files > + New Repository`
2. Enter a name for the repository
3. Click 'Create'
4. From the context menu, click 'Upload files'
5. Click 'Browse'
6. Select the `Get-RefreshHistory.ps1` and `pbi-rest-api.yml` files
7. Click 'Commit'

### Create an Azure DevOps pipeline

This pipeline will run on a schedule to get refresh history.

> **Note:** you can skip this step if you do not plan to use Azure DevOps pipelines to automate running the scripts.

1. In the Azure DevOps portal, navigate to `Pipelines > Pipelines > New pipeline`
2. Select 'Azure Repos Git'
3. Select the Azure DevOps git repository containing the `Get-RefreshHistory.ps1` and `pbi-rest-api.yml` files
4. Select 'Existing Azure Pipelines YAML file'
5. Select the `pbi-rest-api.yml` file
6. Click 'Continue'
7. Click 'Save'
