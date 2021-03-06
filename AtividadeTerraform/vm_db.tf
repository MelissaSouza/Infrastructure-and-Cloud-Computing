resource "azurerm_storage_account" "sa_atividade_tf_db" {
    name                        = "saatividadetfdb"
    resource_group_name         = azurerm_resource_group.rg_atividade_tf.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Atividade Terraform"
    }

    depends_on = [ azurerm_resource_group.rg_atividade_tf ]
}

resource "azurerm_linux_virtual_machine" "vm_atividade_tf_db" {
    name                  = "VMDB"
    location              = var.location
    resource_group_name   = azurerm_resource_group.rg_atividade_tf.name
    network_interface_ids = [azurerm_network_interface.nic_atividade_tf_db.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDBDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "vmdb"
    admin_username = var.user
    admin_password = var.password
    disable_password_authentication = false

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.sa_atividade_tf_db.primary_blob_endpoint
    }

    tags = {
        environment = "Atividade Terraform"
    }

    depends_on = [ azurerm_resource_group.rg_atividade_tf, 
                   azurerm_network_interface.nic_atividade_tf_db, 
                   azurerm_storage_account.sa_atividade_tf_db, 
                   azurerm_public_ip.public_ip_atividade_tf_db ]
}

resource "time_sleep" "wait_30_seconds_db" {
  depends_on = [azurerm_linux_virtual_machine.vm_atividade_tf_db]
  create_duration = "30s"
}

resource "null_resource" "upload_db" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = data.azurerm_public_ip.ip_atividade_tf_data_db.ip_address
        }
        source = "mysql"
        destination = "/home/azureuser"
    }

}

resource "null_resource" "deploy_db" {
    triggers = {
        order = null_resource.upload_db.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = data.azurerm_public_ip.ip_atividade_tf_data_db.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo mysql < /home/azureuser/mysql/script/user.sql",
            "sudo mysql < /home/azureuser/mysql/script/schema.sql",
            "sudo mysql < /home/azureuser/mysql/script/data.sql",
            "sudo cp -f /home/azureuser/mysql/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo service mysql restart",
            "sleep 20",
        ]
    }
}