# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.90.0"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "mtc-RG" {
  name     = "mtc-resources"
  location = "north Europe"
  tags = {

    enviroment = "Dev1"
  }

}


resource "azurerm_virtual_network" "mtc-vNet" {
  name                = "mtc_Network"
  resource_group_name = azurerm_resource_group.mtc-RG.name
  address_space       = ["10.123.0.0/16"]
  location            = azurerm_resource_group.mtc-RG.location
  tags                = { enviroment = "Dev1" }
}



resource "azurerm_subnet" "mtc-sub" {
  name                 = "mtc-subnet1"
  resource_group_name  = azurerm_resource_group.mtc-RG.name
  virtual_network_name = azurerm_virtual_network.mtc-vNet.name

  address_prefixes = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "mtc-SG1" {
  name                = "mtc-ecurity-group1"
  location            = azurerm_resource_group.mtc-RG.location
  resource_group_name = azurerm_resource_group.mtc-RG.name
  tags                = { enviroment = "Dev1" }
}

resource "azurerm_network_security_rule" "mtc-SG1-role" {
  name                        = "test123"
  priority                    = 100
  direction                   = "inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-RG.name
  network_security_group_name = azurerm_network_security_group.mtc-SG1.name
}

resource "azurerm_subnet_network_security_group_association" "SG-Asso" {
  subnet_id                 = azurerm_subnet.mtc-sub.id
  network_security_group_id = azurerm_network_security_group.mtc-SG1.id
}

resource "azurerm_network_interface" "mtc-Nic1" {
  name                = "mtc-netintf"
  location            = azurerm_resource_group.mtc-RG.location
  resource_group_name = azurerm_resource_group.mtc-RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-sub.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc-pubIP1.id
  }
  tags = {
    environment = "Dev1"
  }
}

resource "azurerm_public_ip" "mtc-pubIP1" {
  name                = "mtc-public_ip001"
  resource_group_name = azurerm_resource_group.mtc-RG.name
  location            = azurerm_resource_group.mtc-RG.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Dev1"
  }



}
resource "azurerm_linux_virtual_machine" "mtc-Ubuntu1" {
  name                = "Mtc-Ubuntu-instance1"
  resource_group_name = azurerm_resource_group.mtc-RG.name
  location            = azurerm_resource_group.mtc-RG.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
  azurerm_network_interface.mtc-Nic1.id]

  custom_data = filebase64("customdata.tpl")


  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtc-azurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/mtc-azurekey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]

  }





  tags = {
    environment = "Dev1"
  }


}

data "azurerm_public_ip" "mtc-ip-data" {
  name                = azurerm_public_ip.mtc-pubIP1.name
  resource_group_name = azurerm_resource_group.mtc-RG.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.mtc-Ubuntu1.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
}