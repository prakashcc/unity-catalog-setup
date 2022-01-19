/***************************************************************************************
* Create a Unity Catalog metastore (and the AWS bucket & IAM role if required)
****************************************************************************************/

/***************************************************************************************
* Create AWS Objects for Unity Catalog Metastore
****************************************************************************************/
module "aws_metastore" {
  source = "./modules/aws_uc_resources"

  count = var.create_aws_resources ? 1 : 0

  databricks_account_id  = var.databricks_account_id
  unity_metastore_bucket = var.unity_metastore_bucket
}

/***************************************************************************************
* Create account-level users for UC
****************************************************************************************/
resource "databricks_user" "unity_users" {
  provider  = databricks.mws
  for_each  = toset(concat(var.databricks_users, var.databricks_unity_admins))
  user_name = each.key
}

resource "databricks_group" "admin_group" {
  provider     = databricks.mws
  display_name = var.unity_admin_group
}

resource "databricks_group_member" "admin_group_member" {
  provider  = databricks.mws
  for_each  = toset(var.databricks_unity_admins)
  group_id  = databricks_group.admin_group.id
  member_id = databricks_user.unity_users[each.value].id
}

/***************************************************************************************
* Create the first Unity Catalog metastore and assign it to the chosen workspaces
****************************************************************************************/
module "unity_catalog_metastore" {
  source = "./modules/uc_metastore"

  providers = {
    databricks = databricks.workspace
  }

  databricks_workspace_ids = var.databricks_workspace_ids
  unity_metastore_bucket   = var.create_aws_resources ? module.aws_metastore[0].unity_metastore_bucket : var.unity_metastore_bucket
  unity_metastore_iam      = var.create_aws_resources ? module.aws_metastore[0].unity_metastore_iam : var.unity_metastore_iam
  unity_admin_group        = var.unity_admin_group
}

/***************************************************************************************
* Create quickstart catalogs & quickstart schemas
****************************************************************************************/
resource "databricks_catalog" "quickstart_catalog" {
  provider   = databricks.workspace
  name       = "quickstart_catalog"
  comment    = "A new Unity Catalog catalog called quickstart"
  depends_on = [module.unity_catalog_metastore]
}

resource "databricks_schema" "quickstart_schema" {
  provider     = databricks.workspace
  name         = "quickstart_schema"
  catalog_name = databricks_catalog.quickstart_catalog.name
  comment      = "A new Unity Catalog schema called quickstart_database"
}
