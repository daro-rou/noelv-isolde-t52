# noelv-isolde-t52
ISOLDE Task5.2 -- NOEL-V core
# Initial Setup
The content of this repo has to be a sub-folder in: <instalation path>grlib-gpl-**2024.1-b4291**/designs 
## git credentials
```
git config --global credential.helper cache
```
# Vivado configuration
before you can execute `make vivado` the following has to be configured:  
In terminal run:  
`source ~/vivado.sh`  
Content of vivado.sh:  
```
export  XILINXD_LICENSE_FILE=<vivado licence server>   
source <instal path>/Vivado/2022.1/.settings64-Vivado.sh
```
# Reference configuration
Run `make xconfig`. In the GUI select 'LoadConfiguration from File'. For the filename 
enter `config-isolde-t52`
