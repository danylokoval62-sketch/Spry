# Non-secret values only. Secrets (google_client_secret, database_url) and
# image_uri / recipients / budget_email live in the HCP Terraform workspace.
project_name      = "spry"
google_client_id  = "791114181986-lu23vsj5vegm6mjm9ss5v3klsa37g6v3.apps.googleusercontent.com"
vpc_id            = "vpc-0f6c4766998ed3724"
subnet_ids        = ["subnet-0b01f6f420cdd000c", "subnet-0a2fa6bff9eedd6d4"]
security_group_id = "sg-0736356486cd0109f"
image_uri         = "649089875356.dkr.ecr.eu-central-1.amazonaws.com/spry-backend:21e0fab72ad24abf59659da8d44fffe544c21bc4" # creation only, ignore_changes afterwards
recipients        = "d.koval.pn@ucu.edu.ua"
budget_email      = "d.koval.pn@ucu.edu.ua"
