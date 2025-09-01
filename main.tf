

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${terraform.workspace}-${var.resource_group_name}"
  location = var.location
}

# Virtual Network 1
resource "azurerm_virtual_network" "Vnet" {
  name                ="${terraform.workspace}-${var.vnet_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = var.vnet_address_space
}

# Vnet1-Subnet1
resource "azurerm_subnet" "subnet1" {
  name                 = var.Vnet_subnet1_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.Vnet.name
  address_prefixes     = [var.Vnet_subnet1_address_prefix]
}

resource "azurerm_subnet" "subnet2" {
  name                 = var.Vnet_subnet2_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.Vnet.name
  address_prefixes     = [var.Vnet_subnet2_address_prefix]
}

resource "azurerm_network_security_group" "app" {
 name = "${terraform.workspace}_${length(var.Vm_names)}-nsg1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "FTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "21"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "db" {
  name = "${terraform.workspace}_${length(var.Vm_names)}-nsg2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SQL"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pub_ip" {
  name                = "${terraform.workspace}-${var.public_ip_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_network_interface" "nic" {
  count               = length(var.nic_name)  # ensures flexibility
  name                = "${terraform.workspace}-${var.nic_name[count.index]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  depends_on = [azurerm_subnet.subnet1, azurerm_subnet.subnet2]  # Ensure subnets exist first
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = count.index == 0 ? azurerm_subnet.subnet1.id : azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = count.index == 0 ? azurerm_public_ip.pub_ip.id : null
  }

}

resource "azurerm_network_interface_security_group_association" "app_assoc" {
  network_interface_id      = azurerm_network_interface.nic[0].id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_network_interface_security_group_association" "db_assoc" {
  network_interface_id      = azurerm_network_interface.nic[1].id
  network_security_group_id = azurerm_network_security_group.db.id
}

resource "random_password" "vm_password" {
  count   = 2
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

resource "azurerm_linux_virtual_machine" "vms" {
  count               = 2
  name                = "${terraform.workspace}-${var.Vm_names[count.index]}"                                    #  "linuxvm-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = element(var.Vmsize, count.index)

  admin_username      = var.Vm_usernames[count.index] # Using the list of usernames for each VM
  disable_password_authentication = false
 admin_password      = random_password.vm_password[count.index].result
  
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  
  os_disk {
    name                 = element(var.Vms_os_disk_name, count.index)
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"                          # Standard HDD for OS disk
    disk_size_gb         = element(var.Vm_os_disk_sizes, count.index) # Using element() to get the disk size from the list
  }
  
   source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }


}