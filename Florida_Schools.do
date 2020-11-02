version 16.1

clear all

* Set Working Directory
*cd "*/GitHub/Covid_Florida_Schools"

* Preallocate Panel Data Frame
frame create panel

** Florida Case Line Data
frame create floridacaseline
cwf floridacaseline

import delimited "Florida_COVID19_Case_Line_Data.csv", encoding(UTF-8) clear varnames(1) case(lower)

gen double chartdatetime = clock(substr(chartdate,1,strlen(chartdate)-3),"YMDhms")
format chartdatetime %tc
drop chartdate
gen chartdate = dofc(chartdatetime)
format chartdate %td 

destring age, force replace

* Cases Aug vs Sep-Oct
count if age >= 5 & age <= 17 & month(chartdate) == 8
local aug_kids_cases = r(N)
count if age >= 5 & age <= 17 & (month(chartdate) == 9 | month(chartdate) == 10)
local sept_oct_kids_cases = r(N)

count if month(chartdate) == 8
local aug_cases = r(N)
count if (month(chartdate) == 9 | month(chartdate) == 10)
local sept_oct_cases = r(N)

local kids_case_drop = (`sept_oct_kids_cases' / (td(30oct2020) - td(01sep2020) + 1)) / (`aug_kids_cases' / (td(31aug2020) - td(01aug2020)+1)) 
disp `kids_case_drop'

local all_case_drop = (`sept_oct_cases' / (td(30oct2020) - td(01sep2020) + 1)) / (`aug_cases' / (td(31aug2020) - td(01aug2020)+1)) 
disp `all_case_drop'

local aug_kids_share = `aug_kids_cases' / `aug_cases'
local sept_oct_kids_share = `sept_oct_kids_cases' / `sept_oct_cases'
disp `aug_kids_share' 
disp `sept_oct_kids_share'

* Hospitalisations Aug vs Sep-Oct
count if age >= 5 & age <= 17 & hospitalized == "YES" & month(chartdate) == 8
local aug_kids_hosp = r(N)
count if age >= 5 & age <= 17 & hospitalized == "YES" & (month(chartdate) == 9 | month(chartdate) == 10)
local sept_oct_kids_hosp = r(N)

count if hospitalized == "YES" & month(chartdate) == 8
local aug_hosp = r(N)
count if hospitalized == "YES" & (month(chartdate) == 9 | month(chartdate) == 10)
local sept_oct_hosp = r(N)

local kids_hosp_drop = (`sept_oct_kids_hosp' / (td(30oct2020) - td(01sep2020) + 1)) / (`aug_kids_hosp' / (td(31aug2020) - td(01aug2020)+1)) 
disp `kids_hosp_drop'

local all_hosp_drop = (`sept_oct_hosp' / (td(30oct2020) - td(01sep2020) + 1)) / (`aug_hosp' / (td(31aug2020) - td(01aug2020)+1)) 
disp `all_hosp_drop'

preserve

keep if month(chartdate) >= 8 & month(chartdate) <= 10

gen post = month(chartdate) > 8

bysort age post: gen age_count = _N
bysort post: gen month_count = _N

gen age_share = age_count / month_count

bysort age post: keep if _n == 1
bysort age (post): gen proportional_delta = age_share / age_share[_n-1] - 1
list age_share proportional_delta age post if age>= 5 & age <= 17

keep if post == 1

gen schooltypeage = "Elementary" if age >= 5 & age <= 9
replace schooltypeage = "Middle" if age >= 10 & age <= 13
replace schooltypeage = "High" if age >= 14 & age <= 17

label define SchoolTypeAge_lbl 1 "Elementary" 2 "Middle" 3 "High", replace
encode schooltypeage, gen(schooltypeage_f) label(SchoolTypeAge_lbl)

graph bar (asis) proportional_delta if age >= 5 & age < = 17, over(schooltypeage_f) over(age) nofill bar(1, bcolor(green)) bar(2, bcolor(orange)) bar(3, bcolor(red)) asyvars ytitle(Proportional Increase in Detected Cases) title(Relative Change in Share of Cases After School Reopenings) subtitle(By Age)

restore


** Import School Data Waves

local variables School County CasesPriorWeek StudentsPriorWeek TeachersPriorWeek StaffPriorWeek UnknownPriorWeek SymptomsPriorWeekNo SymptomsPriorWeekYes SymptomsPriorWeekUnknown CasesTotal StudentsTotal TeachersTotal StaffTotal UnknownTotal SymptomsTotalYes SymptomsTotalNo SymptomsTotalUnknown

local totalvariables School County CasesTotal StudentsTotal TeachersTotal StaffTotal UnknownTotal SymptomsTotalYes SymptomsTotalNo SymptomsTotalUnknown

local wavedates `" "Sep 26" "Oct 03" "Oct 10" "Oct 17" "Oct 24" "'

foreach wave in `wavedates'{

local newframe = subinstr("`wave'"," ","",.)
frame create `newframe'	
cwf `newframe'
	
import delimited LineData using "C:\Users\mlilley\Documents\Interesting Questions\Coronavirus\Florida Schools\Florida Schools Covid `wave'.csv", varnames(nonames) rowrange(4) colrange(1:1) clear

* For Schools with Observations in Past Week
local j = 1
local k = 1
foreach var in `variables' {
    // Too many groups, split regex extraction
	if `j' > 9 {
	    gen `var' = regexs(`k') if regexm(LineData, "^[A-Za-z0-9\(\) -.@&\/]+[ ]+[A-Za-z -]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)$") == 1
	local k = `k' + 1
	}
    if `j' <= 9 {
		gen `var' = regexs(`j') if regexm(LineData, "^([A-Za-z0-9\(\) -.@&\/]+)[ ]+([A-Za-z -]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+([0-9]+)[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+$") == 1	    
	local j = `j' + 1
	}
}

* For Schools with Cumulative Observations Only
local j = 1
local k = 1
foreach var in `totalvariables' {
    // Too many groups, split regex extraction
	if `j' > 9 {
	    replace `var' = regexs(`k') if regexm(LineData, "^[A-Za-z0-9\(\) -.@&\/]+[ ]+[A-Za-z -]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+[0-9]+[ ]+([0-9]+)$") == 1 & missing(`var')
	local k = `k' + 1
	}
    if `j' <= 9 {
	    replace `var' = regexs(`j') if regexm(LineData, "^([A-Za-z0-9\(\) -.@&\/]+)[ ]+([A-Za-z -]+)[ ]+([0-9])+[ ]+([0-9])+[ ]+([0-9])+[ ]+([0-9])+[ ]+([0-9])+[ ]+([0-9])+[ ]+([0-9])+[ ]+[0-9]+$") == 1 & missing(`var')
	local j = `j' + 1
	}
}

* Error Check
tab LineData if missing(School) & missing(County)
drop if missing(School) & missing(County)

export delimited using "C:\Users\mlilley\Documents\Interesting Questions\Coronavirus\Florida Schools\Clean\Florida Schools Covid `wave'.csv", replace

** Build Panel
preserve

keep LineData School County CasesTotal CasesPriorWeek StudentsTotal StudentsPriorWeek TeachersTotal TeachersPriorWeek
replace CasesPriorWeek = "0" if missing(CasesPriorWeek)
replace StudentsPriorWeek = "0" if missing(StudentsPriorWeek)
replace TeachersPriorWeek = "0" if missing(TeachersPriorWeek)
gen Date = date("`wave'"+"2020","MDY") 
format Date %td

tempfile panel_`newframe'
save `panel_`newframe''
frame panel: append using `panel_`newframe''

restore

}


** School Type
* Elementary
gen Elementary = regexm(School,"ELEMENTARY")
* Middle
gen Middle = regexm(School,"MIDDLE")
* High
gen High = regexm(School,"HIGH")

tab2 Elementary Middle High

* Universities
gen University = regexm(School,"UNIVERSITY|COLLEGE")==1
* Private
gen Private = regexm(School,"CHRIST|CATHOLIC|AQUINAS|CALVARY|LUTHERAN|PARISH|JEWISH|TEMPLE|YESHIVA|CHAPEL|PREPARATORY|MONTESSORI")

* School Composition
summarize Elementary Middle High University Private


** Cases by School Type
destring CasesTotal StudentsTotal TeachersTotal StaffTotal UnknownTotal CasesPriorWeek StudentsPriorWeek TeachersPriorWeek StaffPriorWeek UnknownPriorWeek, force replace

foreach var in CasesPriorWeek StudentsPriorWeek TeachersPriorWeek StaffPriorWeek UnknownPriorWeek {
    replace `var' = 0 if missing(`var')
}

summarize CasesTotal
display r(sum)
summarize CasesTotal if University == 0
display r(sum)
summarize CasesTotal if Elementary == 1
display r(sum)
summarize CasesTotal if Middle == 1
display r(sum)
summarize CasesTotal if High == 1
display r(sum)

summarize CasesTotal StudentsTotal TeachersTotal StaffTotal UnknownTotal if Elementary == 1
summarize CasesTotal StudentsTotal TeachersTotal StaffTotal UnknownTotal if Middle == 1
summarize CasesTotal StudentsTotal TeachersTotal StaffTotal UnknownTotal if High == 1

summarize CasesTotal StudentsTotal TeachersTotal StaffTotal UnknownTotal if Private == 1
summarize CasesTotal StudentsTotal TeachersTotal StaffTotal UnknownTotal if University == 1

* Spread, Aggregate
tab CasesTotal if Elementary == 1
tab CasesTotal if Middle == 1
tab CasesTotal if High == 1

* Spread, Student - Teacher
tab StudentsTotal TeachersTotal if University == 0

* Fraction of Schools with Positive Student with Positive Teacher
count if StudentsTotal >=1 & TeachersTotal == 0 & University == 0
count if StudentsTotal >= 1 & TeachersTotal >= 1 & University == 0

count if StudentsTotal >=1 & TeachersTotal == 0 & Elementary == 1
count if StudentsTotal >= 1 & TeachersTotal >= 1 & Elementary == 1

count if StudentsTotal >=1 & TeachersTotal == 0 & Middle == 1
count if StudentsTotal >= 1 & TeachersTotal >= 1 & Middle == 1

count if StudentsTotal >=1 & TeachersTotal == 0 & High == 1
count if StudentsTotal >= 1 & TeachersTotal >= 1 & High == 1