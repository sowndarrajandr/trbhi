# Configure terraform to use Azure before proceeding Article https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure#set-up-terraform-access-to-azure
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    features {}

    subscription_id = "<Subscription ID>"
    client_id       = "<Client ID>"
    client_secret   = "<Client Secret>"
    tenant_id       = "<Tenant ID>"
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "TrbhiGroup" {
    name     = "TrbhiRG"
    location = "eastus"

    tags = {
        environment = "TrbhiWorkSamples"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "TrbhiNetwork" {
    name                = "TrbhiVNet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.TrbhiGroup.name

    tags = {
        environment = "TrbhiWorkSamples"
    }
}

# Create subnet
resource "azurerm_subnet" "TrbhiSubnet" {
    name                 = "TrbhiSN"
    resource_group_name  = azurerm_resource_group.TrbhiGroup.name
    virtual_network_name = azurerm_virtual_network.TrbhiNetwork.name
    address_prefix       = "10.0.1.0/24"
}

# Create public IP for Linux
resource "azurerm_public_ip" "TrbhiLinuxPublicIP" {
    name                         = "LinuxPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.TrbhiGroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "TrbhiWorkSamples"
    }
}

# Create public IP for Windows
resource "azurerm_public_ip" "TrbhiWindowsPublicIP" {
    name                         = "WindowsPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.TrbhiGroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "TrbhiWorkSamples"
    }
}

# Create Network Security Group and rule for Linux
resource "azurerm_network_security_group" "TrbhiNetSecGroupLinux" {
    name                = "TrbhiLinuxNSG"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.TrbhiGroup.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "TrbhiWorkSamples"
    }
}

# Create Network Security Group and rule for Windows
resource "azurerm_network_security_group" "TrbhiNetSecGroupWindows" {
    name                = "TrbhiWindowsNSG"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.TrbhiGroup.name
    
    security_rule {
        name                       = "RDP"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "TrbhiWorkSamples"
    }
}


# Create network interface for Linux
resource "azurerm_network_interface" "TrbhiNICLinux" {
    name                      = "LinuxNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.TrbhiGroup.name

    ip_configuration {
        name                          = "LinuxNICConfiguration"
        subnet_id                     = azurerm_subnet.TrbhiSubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.TrbhiLinuxPublicIP.id
    }

    tags = {
        environment = "TrbhiWorkSamples"
    }
}

# Create network interface for Windows
resource "azurerm_network_interface" "TrbhiNICWindows" {
    name                      = "WindowsNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.TrbhiGroup.name

    ip_configuration {
        name                          = "WindowsNICConfiguration"
        subnet_id                     = azurerm_subnet.TrbhiSubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.TrbhiWindowsPublicIP.id
    }

    tags = {
        environment = "TrbhiWorkSamples"
    }
}


# Connect the security group to the network interface Linux
resource "azurerm_network_interface_security_group_association" "TrbhiNSGAssoc" {
    network_interface_id      = azurerm_network_interface.TrbhiNICLinux.id
    network_security_group_id = azurerm_network_security_group.TrbhiNetSecGroupLinux.id
}

# Connect the security group to the network interface Windows
resource "azurerm_network_interface_security_group_association" "TrbhiNSGAssocWin" {
    network_interface_id      = azurerm_network_interface.TrbhiNICWindows.id
    network_security_group_id = azurerm_network_security_group.TrbhiNetSecGroupWindows.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.TrbhiGroup.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "TrbhiBootDiagStorage" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.TrbhiGroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "TrbhiWorkSamples"
    }
}

# Create Ubuntu virtual machine
resource "azurerm_linux_virtual_machine" "TrbhiUbuntuVM" {
    name                  = "TrbhiUbuntu16"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.TrbhiGroup.name
    network_interface_ids = [azurerm_network_interface.TrbhiNICLinux.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "TrbhiOSDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    computer_name  = "TrbhiUbuntu16"
    admin_username = "dinosaur"
    disable_password_authentication = true
        
    admin_ssh_key {
        username       = "dinosaur"
        public_key     = file("/home/dinosaur/.ssh/authorized_keys")
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.TrbhiBootDiagStorage.primary_blob_endpoint
    }

    tags = {
        environment = "TrbhiWorkSamples"
    }
}

# Create Windows-2016 virtual machine
resource "azurerm_windows_virtual_machine" "TrbhiWin16" {
  name                = "TrbhiWin16"
  resource_group_name = azurerm_resource_group.TrbhiGroup.name
  location            = "eastus"
  size                = "Standard_F2"
  admin_username      = "dinosaur"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [azurerm_network_interface.TrbhiNICWindows.id]

  os_disk {
	name              = "TrbhiWin16OSDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}