
%macro connecttooracle;
connect to oracle as DWH (USER=biu_read  PASSWORD="{SAS002}56AFFB0547A4A37417F8135F2EAD17C9" path=CMSDWH preserve_comments buffsize=10000); 
%mend;


