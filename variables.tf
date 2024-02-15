variable "jwt_secret_key" {
  type = string
  sensitive = true
}

variable "lab_account_id" {
  type = string
}

variable "rabbitMQ_user" {
  type = string
  sensitive = true
}

variable "rabbitMQ_password" {
  type = string
  sensitive = true
}