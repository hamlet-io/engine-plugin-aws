[#ftl]

[#assign AWS_RDS_CREATE_SNAPSHOT_TASK_TYPE = "aws_rds_create_snapshot" ]
[#assign AWS_ECR_DOCKER_LOGIN_TASK_TYPE = "aws_ecr_docker_login" ]
[#assign AWS_ECS_SELECT_TASK_TASK_TYPE = "aws_ecs_select_task" ]
[#assign AWS_ECS_RUN_COMMAND_TASK_TYPE = "aws_ecs_run_command" ]
[#assign AWS_ECS_RUN_TASK_TASK_TYPE = "aws_ecs_run_task" ]
[#assign AWS_EC2_SELECT_INSTANCE_TASK_TYPE = "aws_ec2_select_instance" ]
[#assign AWS_KMS_ENCRYPT_VALUE_TASK_TYPE = "aws_kms_encrypt_value" ]
[#assign AWS_KMS_DECRYPT_CIPHERTEXT_TASK_TYPE = "aws_kms_decrypt_ciphertext" ]
[#assign AWS_LAMBDA_INVOKE_FUNCTION_TASK_TYPE = "aws_lambda_invoke_function"]

[#assign AWS_S3_DOWNLOAD_BUCKET_TASK_TYPE = "aws_s3_download_bucket"]
[#assign AWS_S3_DOWNLOAD_OBJECT_TASK_TYPE = "aws_s3_download_object" ]
[#assign AWS_S3_EMPTY_BUCKET_TASK_TYPE = "aws_s3_empty_bucket"]
[#assign AWS_S3_UPLOAD_OBJECT_TASK_TYPE = "aws_s3_upload_object" ]
[#assign AWS_S3_PRESIGN_URL_TASK_TYPE = "aws_s3_presign_url" ]

[#assign AWS_SECRETSMANAGER_GET_SECRET_VALUE_TASK_TYPE = "aws_secretsmanager_get_secret_value"]
[#assign AWS_SES_SMTP_PASSWORD_TASK_TYPE = "aws_ses_smtp_password" ]

[#assign AWS_CFN_CREATE_CHANGE_SET_TASK_TYPE = "aws_cfn_create_change_set"]
[#assign AWS_CFN_EXECUTE_CHANGE_SET_TASK_TYPE = "aws_cfn_execute_change_set"]
[#assign AWS_CFN_DELETE_STACK_TASK_TYPE = "aws_cfn_delete_stack"]
[#assign AWS_CFN_GET_STACK_OUTPUTS_TASK_TYPE = "aws_cfn_get_stack_outputs"]
[#assign AWS_CFN_GET_CHANGE_SET_CHANGES_TASK_TYPE = "aws_cfn_get_change_set_changes_types"]
[#assign AWS_CFN_RUN_STACK_TASK_TYPE = "aws_cfn_run_stack"]

[#assign AWS_RUN_BASH_SCRIPT_TASK_TYPE = "aws_run_bash_script"]
