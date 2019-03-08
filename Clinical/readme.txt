clinical trial demo project SAS code This is a practice/demo project. The data get from the internet, Only a portion of SDTM datasets was created, and only the tables and graphs that applied in the original paper are created.

The result is not 100% match with the study result. This may be the data error during Deidentification. For example, subject NIDA-CSP-1025.157.471603 has been marked as completed the trial. However, all methamphetamine data is missing.

The files are organized as follows: Projests ├─cmacros ├─CSP25P3 │ ├─data │ ├─documents │ └─result └─pub Projects is the root folder for all project. Each real project stored in a folder under this root folder. The custom macros are stored in the cmacros folder. The custom call routines and functions are stored in the pub folder. For easy modify and debug, the project code is split to project_defination.sas, data_prepare.sas, analysis.sas, and reporting.sas. Those codes are called by main.sas to execute the project.

Part of macros related with CDSIC standard is modified from Jack Shostak's code(Implementing CDISC Using SAS An End-to-End Guide)
