This is a partial project code for practice, for the demo, for the memo. The data get from the internet.

Instead of the annotated CRF,  there is the CRF only. In the dictionary, the comments are short. So, it takes a lot of time to track and compare to understand the data and may miss-understand. Because this project is just for the demo, for fun, for a memo..., but not for submission. Therefore, there are only several domains that were created, and only the tables and graphs that applied in the original paper are created.

The result is not a full match with the study result. This may be the data error during Deidentification. For example, subject NIDA-CSP-1025.157.471603 has been marked as completed the trial. However,  all methamphetamine data is missing

The files are organized as follows:
SAS
├─cmacros
├─Clinical
│  ├─data
│  ├─documents
│  ├─pmacro
│  └─result
└─pub
The common custom macros are stored in the cmacros folder.
The project-specific custom macros are stored in the pmacro folder. Part of macros is modified from other macros that get from the internet
The custom call routines and functions are stored in the pub folder.
For easy modify and debug, the project code is split to project_defination.sas, data_prepare.sas, analysis.sas, and reporting.sas. Those codes are called by main.sas to execute the project.	


