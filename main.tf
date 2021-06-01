provider "azurerm" {
  features {}
}

# Create a resource group to assign each VM to
resource "azurerm_resource_group" "azure_rg" {
  name     = "azure_cloud_gaming"
  location = "UK South"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "virtual_net" {
  name                = "virtualnet"
  resource_group_name = azurerm_resource_group.azure_rg.name
  location            = azurerm_resource_group.azure_rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet within the network
resource "azurerm_subnet" "main" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.azure_rg.name
  virtual_network_name = azurerm_virtual_network.virtual_net.name
  address_prefixes       = ["10.0.2.0/24"]
}

# Create Public Ip

# Import the Windows VM Module
module "windows_vm" {
  source = "./windows_vm"
  
  # Variables
  resource_group_name = "azure_cloud_gaming"
  vm_name = "instance1"
  username = "usergamer"
  password = "P@ssw0rdP@ssw0rd"
  subnet_name = azurerm_subnet.main.name
  network_name = azurerm_virtual_network.virtual_net.name
  
  # The following will create a NIC underneath:
  # Subnet
  # Public IP

  depends_on = [
    azurerm_resource_group.azure_rg
  ]
}