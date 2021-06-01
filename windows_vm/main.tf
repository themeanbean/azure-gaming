# Inputs
variable "resource_group_name" {
    type = string
}

variable "username" {
  type = string
}

variable "password" {
  type = string
}

variable "vm_name" {
  type = string
}

variable "subnet_name" {
  description = "The name of the azurerm_subnet to put the VM into"
}

variable "network_name" {
  description = "The name of the azurerm_virtual_network associated with the subnet"
}

variable "vm_type" {
    type = string
    default = "Standard_NV6_Promo"
}

# Outputs
output "vm_ip" {
    value = azurerm_public_ip.vm_public_ip.ip_address
}

# == Data Sources == 

# Obtain resource group from given ID
data "azurerm_resource_group" "azure_rg" {
  name = var.resource_group_name
}

# Obtain Subnet
data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.network_name
  resource_group_name  = var.resource_group_name
}

# == VM Network Infrastructure ==

resource "azurerm_public_ip" "vm_public_ip" {
  name                = "${var.vm_name}-public-ip"
  location            = data.azurerm_resource_group.azure_rg.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}

# Create NIC to attach to VM
resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-main-nic"
  location            = data.azurerm_resource_group.azure_rg.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

# == VM Infrastructure ==

resource "azurerm_windows_virtual_machine" "main" {
  name                = var.vm_name
  resource_group_name = data.azurerm_resource_group.azure_rg.name
  location            = data.azurerm_resource_group.azure_rg.location
  size                = var.vm_type
  admin_username      = var.username
  admin_password      = var.password
  allow_extension_operations = true
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "20h2-pro"
    version   = "latest"
  }
  
  # Uncomment for Spot Instances
  # priority            = "Spot"
  # max_bid_price       = 0.6
  # eviction_policy     = "Deallocate"

  depends_on = [
    azurerm_network_interface.main,
  ]
}

# Install NVIDIA Drivers
resource "azurerm_virtual_machine_extension" "gpudrivers" {
  name                 = "NvidiaGpuDrivers"
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Microsoft.HpcCompute"
  type                 = "NvidiaGpuDriverWindows"
  type_handler_version = "1.3"
  auto_upgrade_minor_version = true
}

# Configure WinRM
resource "azurerm_virtual_machine_extension" "configureforansbile" {
  name                 = "ConfigureAnsible"
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  settings = <<SETTINGS
    {
        "commandToExecute": "powershell .\\ConfigureRemotingForAnsible.ps1",
        "fileUris" : ["https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"]
     }
  SETTINGS
}