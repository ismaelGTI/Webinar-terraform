#Definir proveedor de Azure
provider "azurerm" {
  features {}
  subscription_id = "142a97ec-cf26-4680-9598-bb2f9ecf9485" # Mi suscripción de estudiante Azure
}

# Crear un grupo de recursos
resource "azurerm_resource_group" "nginx" {
  name     = "nginx-resources"
  location = "West Europe"             
}

#Crear una red virtual
resource "azurerm_virtual_network" "nginx" {
  name                = "nginx-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.nginx.location
  resource_group_name = azurerm_resource_group.nginx.name
}

# Crear una subred
resource "azurerm_subnet" "nginx" {
  name                 = "nginx-subnet"
  resource_group_name  = azurerm_resource_group.nginx.name
  virtual_network_name = azurerm_virtual_network.nginx.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Crear una interfaz de red 
resource "azurerm_network_interface" "nginx" {
  name                = "nginx-nic"
  location            = azurerm_resource_group.nginx.location
  resource_group_name = azurerm_resource_group.nginx.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nginx.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nginx.id # Asociar IP pública del recurso creado más adelante 
  }
}

# Crear una máquina virtual Linux con NGINX
resource "azurerm_linux_virtual_machine" "nginx" {
  name                = "nginx-server"
  resource_group_name = azurerm_resource_group.nginx.name
  location            = azurerm_resource_group.nginx.location
  size                = "Standard_B1s" # Tamaño equivalente a t3.micro en AWS
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nginx.id,
  ]
  admin_ssh_key {
    username = "adminuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5gZqjoQhcfhzZxv2FvWETluyM3YgbtB6ryM0rMJlM9IYaSIbIkwwkskPCROVUWFWku2XOlYm+M0WB6ADi88ogUzWArdTBgH5TWtEKnK4BCuilnfaPj+jNs1dTZRm8XyODfp5m13k5d0uK/Fpu41H0lKwSZLB19CDOAITMJcoeodykvini+GtUFXlIwN43/FYVeqVlwje4rDjl0lK/obDPNZ9r08SwpZgWosKXQ+eB+QU9djRXzRyBUw+a4ys6laDlUmaIuSemPfBjYVs9xKlEMJ8QS+lxGag8ddGFokZnM6EjoJtbl8ODiicPwV6AYg4Lk15v4lUjePtDtnguLRFF00fFnr0riq9QSbkS0jqhJskDb2hXOCorqLLoL6zpvYVaq8TwL4nbbaJyN8sZxUjyBm1WelgF5F0e5V7YR3N0x1UIkT0oEo6LYtipf4I4p9F9wlM0Ij+WJXe4iHTuWwZ8T3VV4YPRVHBb93Uc+iSIzgRZlAuWYo7A6lWcMtvIJexHoQi4sn7mJ9aoyBjcNpyC7USqDqqQ8xIVMiUnWuTJdcfp1g2V86qybxcx4qYJFq/3u5oAB1099/SXflWmNxTnqX4RdSx3cs70pZRB9F9XMYQ0U2pw61Y9m/OHkxRDDMtOe/hGUdv+9Kp8XtRK2sk0ywgTk19Wav3IpP/7dT32Vw== dir\\jose.ismael.marin@c11-msdbqx6d2ci"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2" # Versión compatible con NGINX
    version   = "22.04.202506200" #Latest
  }

  #Script para instalar NGINX
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    EOF
  )
}

  # Acceso público a la VM y sus servicios
# Crear una IP pública
resource "azurerm_public_ip" "nginx" {
  name                = "nginx-public-ip"
  resource_group_name = azurerm_resource_group.nginx.name
  location            = azurerm_resource_group.nginx.location
  allocation_method   = "Static" 
}

# Crear un grupo de seguridad de red para permitir tráfico SSH(22) Y HTTP(80)
resource "azurerm_network_security_group" "nginx" {
  name                = "nginx-nsg"
  location            = azurerm_resource_group.nginx.location
  resource_group_name = azurerm_resource_group.nginx.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nginx" {
  network_interface_id      = azurerm_network_interface.nginx.id
  network_security_group_id = azurerm_network_security_group.nginx.id
}



