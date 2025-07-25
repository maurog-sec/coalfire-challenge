#!/bin/bash
terraform init
terraform plan -out=tfplan
terraform graph -plan=tfplan | dot -Tpng -o diagram.png
echo "Diagram generated at diagram.png"
