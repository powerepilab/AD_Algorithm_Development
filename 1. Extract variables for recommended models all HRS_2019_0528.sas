libname x 'F:\power\HRS\DerivedData\AD_Disparities_AlgorithmDev\Data 2019_0308 (Medicare Dx)';
libname adams 'F:\power\HRS\ADAMS CrossWave';
libname raw 'F:\power\HRS\HRS data (raw)\SAS datasets';
libname rand 'F:\power\HRS\RAND_HRS\sasdata\2014(V2)';
options fmtsearch = (rand.formats);

/**********************************************************************************************************************
*
*	Created 2019_0308 (Updated 2019_0528)
*		- Extracts Variables used in Hurd model, Expert Model, and LASSO Model for application to 1998-2014 HRS waves
*			- HRS core: proxy-cognition, volunteering and helping others
*			- RAND all others
*		- 1994 - 2014:
*			- self-cognition, proxy-cognition (where available), IADLS, CESD (for creating change)
*		- 1996-2014:
*			- social engagement (for creating change)
*		- 1998-2014: 
*			- all others
*
*		- Change variables in LASSO Model (standardized to number waves skipped + 1)
*
*			- self-and proxy-cognition
*				- 4 indicators for current and last wave participation (though only one enters final model) and related change/lag variables
*						- 1. current-self_last-self: change in self-cognition
*						- ***2. current-self_last-proxy: go back further (limit to 3 prior waves) to find wave with self-cognition to compute change in self-cognition
*						- 3. current-proxy_last-proxy: change in proxy-cognition
*						- 4. current-proxy_last-self: lagged self-cognition 
*
*
***************************************************************************************/

%let dt=2019_0308;
 
/****************************************************
*	Create dataset
*****************************************************/

*gender, race/ethnicity, education;
data base; set rand.randhrs1992_2014v2 (keep = hhid pn hacohort ragender 
									 raedegrm /*highest degree achieved*/
									 raracem /*1=White, 2=Black/AA, 3=Other*/
									 rahispan); /*0=NotHispanic, 1=Hispanic*/

/*sex*/
	if ragender = 1 then do; male = 1; female = 0; end;
	else if ragender = 2 then do ; male = 0; female = 1; end;
		label male = "1=male, 0=female";
		label female = "1=female, 0=male";

/*race/ethnicity*/

	*hispanic;
	if rahispan = 1 then hispanic =1; 
	if rahispan = 0 then hispanic =0;
		label hispanic = "1=hispanic, 0=non-Hispanic";
	*NH_white;
	if rahispan = 0 and raracem = 1 then NH_white = 1; else NH_white = 0;
		label NH_white = "1=NH_white, 0=Hispanic, NH_black, NH_other";
	*NH_black;
	if rahispan = 0 and raracem = 2 then NH_black = 1; else NH_black = 0;
		label NH_black = "1=NH_black, 0=Hispanic, NH_white, NH_other";
	*NH_other;
	if rahispan = 0 and raracem = 3 then NH_other = 1; else NH_other = 0;
		label NH_other= "1=NH_other, 0=Hispanic, NH_white, NH_black";

/*education - LTHS, HSgrad, grater than HS*/
	if raedegrm in (0) then do;
		LTHS = 1;
		HSGED = 0;
		GTHS = 0;
	end; 
	else if raedegrm in (1, 2, 3) then do;
		LTHS = 0;
		HSGED = 1;
		GTHS = 0;
	end;
	else if raedegrm in (4, 5, 6, 7, 8) then do;
		LTHS = 0;
		HSGED = 0;
		GTHS = 1;
	end;
	label LTHS = "1=Less than HS/GED";
	label HSGED = "1=High school or GED degree";
	label GTHS = "1=Some college, college grad, or higher degree";

	drop ragender raedegrm rahispan raracem;
	proc sort; by hhid pn;
run;

/***************************************************************************************************************************************
Cognition predictors from RAND, interview wave participation, proxy indicators;
	- start in wave 2 (1994) where all variables are consistently available for all cohorts - needed for computing change variables
		- wave 2 name for immediate/delayed word recall different, extract separately
********************************************************************************************************************************************/
*wave 94;
%macro ext (w, y);
/*extract*/
	data wave_&y; 
		set rand.randhrs1992_2014v2 
		(keep = hhid pn 
			inw&w /*whether participated in interview*/
			r&w.proxy /*indicator for proxy interview*/
			/*Cognition for self-respondents: TICS items*/
			r&w.mo r&w.dy r&w.yr r&w.dw /* dates - for each one: 0=Incorrect, 1=Correct */
			r&w.bwc20 /* TICS serial backwards count 0=Incorrect, 1=CorrectTry2, 2=CorretTry1 */
			r&w.ser7 /* TICS serial 7's 0-5 */
			r&w.cact /*TICS object naming (cactus) - 0=Incorrect, 1=Corect*/
			r&w.scis /*TICS object naming (scissors) - 0=Incorrect, 1=Corect*/
			r&w.pres r&w.vp /*Wu: TICS president and VP naming - 0=Incorrect, 1=Correct*/
			r2aimr10 /* immediate word recall - 0-10 */
			r2adlr10); /* delayed word recall 0-10 */
	
		*participation variable;
		rename inw&w = inw_&y;
			label inw&w = "participation in wave &y";

		*proxy indicator;
		if r&w.proxy in (0, 1) then proxy_&y = r&w.proxy;
		label proxy_&y = "proxy respondent in wave _&y";

		*immediate and delayed word recall;
		if 0 le r2aimr10 le 10 then iword_&y = r2aimr10;
			label iword_&y  = "immediate word recall: 0-10, wave &y";
		if 0 le r2adlr10 le 10 then dword_&y = r2adlr10;
			label dword_&y = "delayed word recall: 0-10, wave &y";
		iwordsq_&y = iword_&y * iword_&y; 
			label iwordsq_&y = "iword_squared: 0-100, wave &y";

		/*TICS variables - asked of everyone*/
		if 0 le r&w.ser7 le 5 then ser7_&y = r&w.ser7;
			label ser7_&y = "TICS serial 7 score: 0-5, wave &y";
		*backwards count, scale 0-2 (for LASSO);
		if 0 le r&w.bwc20 le 2 then bwc_&y = r&w.bwc20;
			label bwc_&y = "TICS backwards count score: 0-2, wave &y";
		*backwards count, scale 0-1 (for Hurd);
		if bwc_&y = 2 then bwc1_&y = 1; else if bwc_&y in (0, 1) then bwc1_&y = 0; 
		label bwc1_&y = "BackwardsCount: 1=Correct 1st attempt ONLY, 0=Incorrect or Correct 2nd attempt, wave &y";

		drop r2aimr10 r2adlr10 r&w.proxy r&w.ser7 r&w.bwc20; 
	run;

	/*code TICS variables not asked of reinterviewees aged < 65 - assume correct*/
	%macro tics(v, var);
		data wave_&y; 
			set wave_&y;

			if r&w&v = .N then &var._&y = 1; /*special missing code for reinterviewees aged < 65*/
			else if r&w&v in (0, 1) then &var._&y = r&w&v;
				label &var._&y = "TICS &var: 0=incorrect, 1 = correct (assumed correct for reinterviewees < 65 if not asked), wave &y)";

			drop r&w&v;
		run;
	%mend;
	%tics(mo, ticsmo) %tics(dy, ticsdt) %tics(yr, ticsyr) %tics(dw, ticswk) 
	%tics(pres, pres) %tics(vp, vp) %tics(cact, cact) %tics(scis, scis)

	data wave_&y; 
		set wave_&y;

		/*Wu algorithm TICS score for LASSO model*/
		tics13_&y = ticsmo_&y + ticsdt_&y + ticsyr_&y + ticswk_&y + cact_&y + pres_&y + vp_&y + ser7_&y + (bwc_&y = 2); /*0-13;  only counts first attempt at backward counting*/
			label tics13_&y = "Wu TICS: 0-13, wave &y";
		tics13sq_&y = tics13_&y * tics13_&y; 
			label tics13sq_&y = "TICS_squared: 0-169, wave &y";

		/*create name_wrong and date_wrong dummies*/
		if ticsmo_&y = 0 OR ticsdt_&y = 0 OR ticsyr_&y = 0 OR ticswk_&y = 0 then date_wrong_&y = 1;
		else if ticsmo_&y = 1 AND ticsdt_&y = 1 AND ticsyr_&y = 1 AND ticswk_&y = 1 then date_wrong_&y = 0;
			label date_wrong_&y = "answered at least one of four date recall items incorrectly, wave &y";

		if cact_&y = 0 OR scis_&y = 0 OR pres_&y = 0 OR vp_&y = 0 then name_wrong_&y = 1;
		else if cact_&y = 1 AND scis_&y = 1 AND pres_&y = 1 AND vp_&y = 1 then name_wrong_&y = 0;
			label name_wrong_&y = "answered at least one of naming/recall items incorrectly, wave &y";

		/*create date recall summary score for Hurd*/
		date_recall_&y = ticsmo_&y+ticsdt_&y+ticsyr_&y+ticswk_&y; 
		label date_recall_&y = "sum of scores for date recall items: date, week, month, year";

		drop ticsmo_&y ticsdt_&y ticsyr_&y ticswk_&y;

		proc sort; by hhid pn;
	run;

	/*merge to main dataset*/
	data base;
		merge base wave_&y;
		by hhid pn;

		proc means nolabels; var iword_&y name_wrong_&y date_recall_&y date_wrong_&y;
	run;

%mend;
%ext(2, 94)

*waves 96-12 - additional extract age;
%macro ext (w, y);
/*extract*/
	data wave_&y; 
	set rand.randhrs1992_2014v2 
	(keep = hhid pn 
		inw&w /*whether participated in interview*/
		r&w.agey_e /*age in years - at end of interview month*/
		r&w.proxy /*indicator for proxy interview*/
		/*Cognition for self-respondents: TICS items*/
		r&w.mo r&w.dy r&w.yr r&w.dw /* dates - for each one: 0=Incorrect, 1=Correct */
		r&w.bwc20 /* TICS serial backwards count 0=Incorrect, 1=CorrectTry2, 2=CorretTry1 */
		r&w.ser7 /* TICS serial 7's 0-5 */
		r&w.cact /*TICS object naming (cactus) - 0=Incorrect, 1=Corect*/
		r&w.scis /*TICS object naming (scissors) - 0=Incorrect, 1=Corect*/
		r&w.pres r&w.vp /*Wu: TICS president and VP naming - 0=Incorrect, 1=Correct*/
		r&w.imrc /* immediate word recall - 0-10 */
		r&w.dlrc); /* delayed word recall 0-10 */

		*participation variable;
		rename inw&w = inw_&y;
			label inw&w = "participation in wave &y";

		*age - centered at 70 for Expert & LASSO Models;
		hrs_age70_&y = r&w.agey_e - 70; 
			label hrs_age70_&y = "Age at interview centered at 70, wave &y";
		*age squared - for Expert Model;
		hrs_age70sq_&y = hrs_age70_&y*hrs_age70_&y;
			label hrs_age70sq_&y = "Age (centered at 70) squared, wave &y";
		*age categories - for Hurd;
		hagecat_&y = 1 + (r&w.agey_e ge 75) + (r&w.agey_e ge 80) + (r&w.agey_e ge 85) + (r&w.agey_e ge 90);
		label hagecat_&y  = "Hurd HRS age category 1=<75, 2=75-79, 3=80-84, 4=85-89, 5=90+, wave &y";
		if hagecat_&y NE . then do;
			hagecat75_&y = (hagecat_&y = 2); label hagecat75_&y = "age 75-79, wave &y";
			hagecat80_&y = (hagecat_&y = 3); label hagecat80_&y = "age 80-84, wave &y";
			hagecat85_&y = (hagecat_&y = 4); label hagecat85_&y = "age 85-89, wave &y";
			hagecat90_&y = (hagecat_&y = 5); label hagecat90_&y = "age 90+, wave &y";
		end;

		*proxy indicator;
		if r&w.proxy in (0, 1) then proxy_&y = r&w.proxy;
		label proxy_&y = "proxy respondent in wave _&y";

		*immediate and delayed word recall;
		if 0 le r&w.imrc le 10 then iword_&y = r&w.imrc;
			label iword_&y = "immediate word recall: 0-10, wave &y";
		if 0 le r&w.dlrc le 10 then dword_&y = r&w.dlrc;
			label dword_&y = "delayed word recall: 0-10, wave &y";
		iwordsq_&y = iword_&y * iword_&y; 
			label iwordsq_&y = "iword_squared: 0-100, wave &y";

		/*TICS variables - asked of everyone*/
		if 0 le r&w.ser7 le 5 then ser7_&y = r&w.ser7;
			label ser7_&y = "TICS serial 7 score: 0-5, wave &y";
		*backwards count, scale 0-2 (for LASSO);
		if 0 le r&w.bwc20 le 2 then bwc_&y = r&w.bwc20;
			label bwc_&y = "TICS backwards count score: 0-2, wave &y";
		*backwards count, scale 0-1 (for Hurd);
		if bwc_&y = 2 then bwc1_&y = 1; else if bwc_&y in (0, 1) then bwc1_&y = 0; 
		label bwc1_&y = "BackwardsCount: 1=Correct 1st attempt ONLY, 0=Incorrect or Correct 2nd attempt, wave &y";

		drop r&w.imrc r&w.dlrc r&w.proxy r&w.ser7 r&w.bwc20; 
	run;

	/*code TICS variables not asked of reinterviewees aged < 65*/
	%macro tics(v, var);
		data wave_&y; 
			set wave_&y;

			if r&w&v = .N then &var._&y = 1; /*special missing code for reinterviewees aged < 65*/
			else if r&w&v in (0, 1) then &var._&y = r&w&v;
				label &var._&y = "TICS &var: 0=incorrect, 1 = correct (assumed correct for reinterviewees < 65 if not asked), wave &y)";

			drop r&w&v;
		run;
	%mend;
	%tics(mo, ticsmo) %tics(dy, ticsdt) %tics(yr, ticsyr) %tics(dw, ticswk) 
	%tics(pres, pres) %tics(vp, vp) %tics(cact, cact) %tics(scis, scis)

	*create additional variables;
	data wave_&y; 
		set wave_&y;
		
		/*Wu algorithm TICS score for LASSO model*/
		tics13_&y = ticsmo_&y + ticsdt_&y + ticsyr_&y + ticswk_&y + cact_&y + pres_&y + vp_&y + ser7_&y + (bwc_&y = 2); /*0-13;  only counts first attempt at backward counting*/
			label tics13_&y = "Wu TICS: 0-13, wave &y";
		tics13sq_&y = tics13_&y * tics13_&y; 
			label tics13sq_&y = "TICS_squared: 0-169, wave &y";

		/*create name_wrong and date_wrong dummies*/
		if ticsmo_&y = 0 OR ticsdt_&y = 0 OR ticsyr_&y = 0 OR ticswk_&y = 0 then date_wrong_&y = 1;
		else if ticsmo_&y = 1 AND ticsdt_&y = 1 AND ticsyr_&y = 1 AND ticswk_&y = 1 then date_wrong_&y = 0;
			label date_wrong_&y = "answered at least one of four date recall items incorrectly, wave &y";

		if cact_&y = 0 OR scis_&y = 0 OR pres_&y = 0 OR vp_&y = 0 then name_wrong_&y = 1;
		else if cact_&y = 1 AND scis_&y = 1 AND pres_&y = 1 AND vp_&y = 1 then name_wrong_&y = 0;
			label name_wrong_&y = "answered at least one of four naming/recall items incorrectly, wave &y";

		/*create date recall summary score for Hurd*/
		date_recall_&y = ticsmo_&y+ticsdt_&y+ticsyr_&y+ticswk_&y; 
		label date_recall_&y = "sum of scores for date recall items: date, week, month, year";

		drop ticsmo_&y ticsdt_&y ticsyr_&y ticswk_&y;

		proc sort; by hhid pn;
	run;

	/*merge to main dataset*/
	data base;
		merge base wave_&y;
		by hhid pn;

		proc means nolabels; var iword_&y tics13_&y name_wrong_&y date_wrong_&y inw_&y;
	run;
%mend;
%ext(3, 96) %ext(4, 98)
%ext(5, 00) %ext(6, 02) %ext(7, 04) %ext(8, 06) %ext(9, 08)
%ext(10, 10) %ext(11, 12) %ext(12, 14)

/***************************************************************************************
	Need IADLs in 94/96 for purposes of computing change
*****************************************************************************************/
*waves 94-96;
%macro ext(w, y);
data wave_&y;
set rand.randhrs1992_2014v2 
	(keep = hhid pn 
			r&w.iadlza); /*IADLs: phone, money, meds, shop, meal*/
		
		if 0 le r&w.iadlza le 5 then iadl_&y = r&w.iadlza;
			label iadl_&y = "IADLs: phone, money, meds, shop, meal, wave &y";

	drop r&w.iadlza;

	proc sort; by hhid pn;

run;

data base;
	merge base wave_&y (keep = hhid pn iadl_&y);
	by hhid pn;

	proc means nolabels; var iadl_&y ;
run;
%mend;
%ext(2, 94) %ext(3, 96)

/*social engagement change variables not used - do not need prior to 1998*/

/****************************************************************************************
Other predictors from RAND needed starting 1998:
	- ADLs 
	- change in ADLs (computed by RAND)
	- IADLs 
	- dressing, eating, bathing, using phone (for LASSO Model)
	- self-report health, 
	- change in self-report health 
	- High blood pressure (has doctor ever told you)
	- Diabetes 
	- BMI
		- center at 25 (average value)
		- code to underweight(< 18.5), normal(18.5- <25), overwight(25 - <30), obese(30+) https://www.cdc.gov/obesity/adult/defining.html
	- Drinking
		- code to 3 level: non-drinker, light/moderate drinking, more than moderate (according to govt guidelines: men: moderate = 2 drinks/day, women: moderate = 1 drink/day (NOT averaged))
	- Partnerpreset
	- Time since retirement
************************************************************************************/

/*waves 98-14*/	
%macro ext(w, y);
	data wave_&y;
		set rand.randhrs1992_2014v2 
		(keep = hhid pn ragender
				r&w.wtcrnh /*sampling weight (for both community- and NH-dwelling individuals)*/
				r&w.adla r&w.adlc /*ADLs | change in ADLs */
				r&w.adlf /*flag for wave missed for computing change (i.e. interview waves skipped) - same as flag for change in self-report health - only need one*/
				r&w.iadlza /*IADLs: phone, money, meds, shop, meal*/
				r&w.eata r&w.batha r&w.dressa r&w.phonea
				r&w.shlt r&w.shltc /*self-reported health: 1=excellent, 5=poor | (RAND computed) change in self-reported health: positive = deteriorate*/
				r&w.hibp r&w.diab /*High BP | diabetes: 0=No, 1=Yes, 3=Disp prev record and has, 4=Disp prev record and no, 5=Disp prev record and DK*/
				r&w.bmi /*BMI*/
				r&w.drinkn /*# drinks/day when drinks*/
				r&w.mstat /*marital status: 1=married, 2=married,sp absent, 3=partnered, 4=separated, 5 = divorced, 6=seaprated/divorced, 7=widowed, 8=nevermarried*/
				r&w.sayret r&w.retyr r&w.retmon r&w.iwendy r&w.iwendm); /*retirement year and month | interview year and month*/

		*adls, iadls;
		if 0 le r&w.adla le 5 then adl_&y = r&w.adla;
			label adl_&y = "ADLs: bath, eat, dress, walk across room, bed, wave &y";
		if 0 le r&w.iadlza le 5 then iadl_&y = r&w.iadlza;
			label iadl_&y = "IADLs: phone, money, meds, shop, meal, wave &y";

		if r&w.iadlza = 0 then iadl_d_&y = 0; 
		else if r&w.iadlza ge 1 then iadl_d_&y = 1;
			label iadl_d_&y = "has at least one IADL limitation, wave &y";

		if  r&w.adla = 0 then adl_d_&y = 0; 
		else if  r&w.adla ge 1 then adl_d_&y = 1;
			label adl_d_&y = "has at least one ADL limitation, wave &y";

		if r&w.eata in (0, 1) then eat_&y = r&w.eata;
			label eat_&y = "Difficulty eating, wave_&y";
		if r&w.batha in (0, 1) then bath_&y = r&w.batha;
			label bath_&y = "Difficulty bathing, wave_&y";
		if r&w.dressa in (0, 1) then dress_&y = r&w.dressa;
			label dress_&y = "Difficulty dressing, wave_&y";
		if r&w.phonea in (0, 1) then phone_&y = r&w.phonea;
			label phone_&y = "Difficulty using phone, wave_&y";

		*self report health;
		if r&w.shlt in (1, 2) then health_d1_&y = 1; 
		else if r&w.shlt in (3, 4, 5) then health_d1_&y = 0;
			label health_d1_&y = "Self-reported health status: 1(excellent/very good) - 5(good/fair/poor), wave &y";

		if r&w.shlt in (1, 2, 3) then health_d2_&y = 1; 
		else if r&w.shlt in (4, 5) then health_d2_&y = 0;
			label health_d2_&y = "Self-reported health status: 1(excellent/very good/good) - 5(fair/poor), wave &y";

		*change flag;
		if r&w.adlf not in (., .M) then randchf_&y = r&w.adlf;
			label randchf_&y = "(from RAND) number waves skipped for computing change, wave &y";

		*create change in ADLs (non-standardized) for Hurd;
		if -5 le r&w.adlc le 5 then adlch_&y = r&w.adlc;

		*create standardized change in ADLs and health status ;
		if randchf_&y in (0, 1, 2) then do;
			if -4 le r&w.shltc le 4 then healthst_sdch2_&y = r&w.shltc/(randchf_&y + 1);
			if -5 le r&w.adlc le 5 then adl_sdch2_&y = r&w.adlc/(randchf_&y + 1);
		end;
			label adl_sdch2_&y = "standardized (RAND computed) change in ADLs (max 2 waves missed), no limit to waves missed, wave &y";
			label healthst_sdch2_&y = "standardized (RAND computed) change in self-reported health status (max 2 waves missed), wave &y";

		*high blood pressue / diabetes: 1=Yes, 3=Dispute previous and yes | 0=No, 4=dispute prev and no | 5=disp prev and DK (leave missing in recode);
		if r&w.hibp in (1, 3) then hibp_&y = 1; else if  r&w.hibp in (0, 4) then hibp_&y = 0; 
			label hibp_&y = "has doctor told you that you have hyptertension or high BP, 1=Yes, 0=No, wave &y";
		if r&w.diab in (1, 3) then diab_&y = 1; else if  r&w.diab in (0, 4) then diab_&y = 0; 
			label diab_&y = "has doctor told you that you have diabetes, 1=Yes, 0=No, wave &y";

		*BMI;
		bmi25c_&y = r&w.bmi - 25; 
			label bmi25c_&y = "BMI centered at 25, wave &y";
		if r&w.bmi > 1 then bmicat_&y = 1 + (r&w.bmi ge 18.5) + (r&w.bmi ge 25) + (r&w.bmi ge 30);
			label bmicat_&y = "BMI/weight category: 1=Underweight, 2=Normal, 3=Overweight, 4=obese, wave &y";

		*drinking;
		if r&w.drinkn = 0 then drinklvl_&y = 0;
		else if ragender = 1 then do;
			if r&w.drinkn in (1, 2) then drinklvl_&y = 1;
			else if r&w.drinkn > 2 then drinklvl_&y = 2;
		end;
		else if ragender = 2 then do;
			if r&w.drinkn = 1 then drinklvl_&y = 1;
			else if r&w.drinkn > 1 then drinklvl_&y = 2;
		end;
		label drinklvl_&y = "Amount alcohol consumed: 0=None, 1=Moderate (1 drink/day for women, 2 drinks/day for men), 2=More than Moderate, wave &y";
		
		*partnerpresent;
		if r&w.mstat in (1, 3) then partnerpres_&y = 1;
		else if r&w.mstat in (2, 4, 5, 6, 7, 8) then partnerpres_&y = 0;
			label partnerpres_&y = "Partnered: 1=Married (spouse present) or partnered, 0=Married(spouse absent)/separated/divorced/widowed/never married, wave &y";
	
		*retirement status and years;
		if r&w.sayret in (0, 3) then retstat_&y = r&w.sayret;
		else if r&w.sayret = 2 then retstat_&y = 1;
		else if r&w.sayret = 1 then retstat_&y = 2;
		else if r&w.sayret = .S then retstat_&y = -1;
	
		if retstat_&y = 0 then retyrs_&y = 0;
		else if retstat_&y in (1, 2) then do;	
			if r&w.retmon not in (.Q, .S, .N, .M) then retyrs_&y = round((mdy(r&w.iwendm,1,r&w.iwendy) - mdy(r&w.retmon, 1, r&w.retyr))/365.25);
			else retyrs_&y = round((mdy(r&w.iwendm,1,r&w.iwendy) - mdy(7, 1, r&w.retyr))/365.25); /*for those missing month of retirement - use mid-year*/
		end;
		if retstat_&y in (1, 2) and retyrs_&y = 0 then retyrs_&y = 0.5; /*for those whose retirement years got rounded to 0, set to 0.5*/

		if retstat_&y in (-1, 3) then retyrcat_&y = -1;
		else if retstat_&y = 0 then retyrcat_&y = 0;
		else if retyrs_&y NE . then retyrcat_&y = 1 + (retyrs_&y > 2) + (retyrs_&y > 5) + (retyrs_&y > 10) + (retyrs_&y > 15);
			label retyrcat_&y = "Years retired: -1=Proxy/Irrelevant, 0=NotRet, 1=0-2yrs, 2=3-5yrs, 3=6-10yrs, 4=11-15yrs, 5=15yrs+, wave_&y";

		*keep interview year and month variables;
		rename r&w.iwendm = iwmo_&y;
			label r&w.iwendm = "interview month";
		rename r&w.iwendy = iwyr_&y;
			label r&w.iwendy = "interview year";

		*sampling weight;
		rename r&w.wtcrnh = hrs_wgt_&y;

		drop ragender r&w.adla r&w.adlc r&w.adlf r&w.iadlza r&w.eata r&w.batha r&w.dressa r&w.phonea
			 r&w.shlt r&w.shltc r&w.hibp r&w.diab r&w.bmi r&w.drinkn r&w.mstat r&w.sayret r&w.retyr r&w.retmon retstat_&y retyrs_&y;
		proc sort; by hhid pn;
	run;

	data base;
		merge base wave_&y;
		by hhid pn;
	run;

%mend;
%ext(4, 98)
%ext(5, 00)	%ext(6, 02) %ext(7, 04) %ext(8, 06) 
%ext(9, 08) %ext(10, 10) %ext(11,12) %ext(12, 14)

/***************************************************************************************
Wu predictors from HRS core
	- proxy-rated memory health
	- Jorm IQCODE
	- start in 1996 for computing change
************************************************************************************/
%macro jorm (prmem, base, better, worse, first, y, raw);
data wave_&y; set raw.&raw (keep = hhid pn &prmem &base &better &worse); 
	array base [16] &base;
	array better [16] &better;
	array worse [16] &worse;
	array jorm [16] jorm_&y._1 - jorm_&y._16;

	if &first NE . then do;

		iqcode_dkrf_&y = 0; 

		do i = 1 to 16;
			
			if base[i] = 1 then do; /*better*/
				if better[i] = 1 then jorm[i] = 1; /*much better*/
				else if better[i] in (2, 8, 9) then jorm[i] = 2; /*a bit better*/
			end;

			else if base[i] = 2 then jorm[i] = 3; /*same*/

			else if base[i] = 3 then do; /*worse*/
				if worse[i] in (4, 8, 9) then jorm[i] = 4; /*a bit worse*/
				else if worse[i] = 5 then jorm[i] = 5; /*much worse*/
			end;

			else if base[i] in (8, 9) then do; /*8=dk/na, 9=rf*/
				jorm[i] = .;
				iqcode_dkrf_&y = iqcode_dkrf_&y + 1; /*count of dk/na*/
			end;

			else if base[i] = 4 then do; /*4=NotApplicable - do NOT count as dk/rf*/
				jorm[i] = .;
			end;

		end;
		
		IQCODE_&y = mean (of jorm[*]); /*mean IQCODE score over non-missing items*/
		if iqcode_dkrf_&y > 3 then IQCODE_&y = .;	/* set to missing 4+ dk/rf*/
	end;

	IQCODE5_&y = IQCODE_&y - 5; 
	label IQCODE5_&y = "Jorm IQCODE score (centered at 5): -4(much better) to 0(much worse), set to missing if 4+ items dk/nf, wave &y";

	if &prmem in (1, 2, 3, 4, 5) then pr_memsc5_&y = &prmem - 5; 
	label pr_memsc5_&y = "proxy mem score centered at 5: -4(excellent) to 0(poor), wave &y";

proc sort; by hhid pn;
run;

data base;
	merge base wave_&y (keep = hhid pn IQCODE_&y IQCODE5_&y pr_memsc5_&y);
	by hhid pn;

	proc means nolabels; var IQCODE5_&y pr_memsc5_&y;
run;
%mend;

*Not available for wave 2 (1993/1994);
*1995 and 1996 - extract and combine both to same _06 suffix;
%jorm (D1056,
	   D1072 D1077 D1082 D1087 D1092 D1097 D1102 D1107 D1112 D1117 D1122 D1127 D1132 D1135 D1138 D1141, 
	   D1073 D1078 D1083 D1088 D1093 D1098 D1103 D1108 D1113 D1118 D1123 D1128 D1133 D1136 D1139 D1142,
       D1074 D1079 D1084 D1089 D1094 D1099 D1104 D1109 D1114 D1119 D1124 D1129 D1134 D1137 D1140 D1143,
	   D1072, 95, a95pc_r);
%jorm (E1056,
	   E1072 E1077 E1082 E1087 E1092 E1097 E1102 E1107 E1112 E1117 E1122 E1127 E1132 E1135 E1138 E1141, 
	   E1073 E1078 E1083 E1088 E1093 E1098 E1103 E1108 E1113 E1118 E1123 E1128 E1133 E1136 E1139 E1142,
       E1074 E1079 E1084 E1089 E1094 E1099 E1104 E1109 E1114 E1119 E1124 E1129 E1134 E1137 E1140 E1143,
	   E1072, 96, h96pc_r);
data base; set base;
	if IQCODE5_96 = . then IQCODE5_96 = IQCODE5_95;
	if pr_memsc5_96 = . then pr_memsc5_96 = pr_memsc5_95;
	proc means; var IQCODE5_96 pr_memsc5_96;
run;
data base; set base (drop = IQCODE5_95 pr_memsc5_95); run;
*1998;
%jorm (F1373,
	   F1389 F1394 F1399 F1404 F1409 F1414 F1419 F1424 F1429 F1434 F1439 F1444 F1448 F1451 F1454 F1457, 
	   F1390 F1395 F1400 F1405 F1410 F1415 F1420 F1425 F1430 F1435 F1440 F1445 F1449 F1452 F1455 F1458,
       F1391 F1396 F1401 F1406 F1411 F1416 F1421 F1426 F1431 F1436 F1441 F1446 F1450 F1453 F1456 F1459,
	   F1389, 98, h98pc_r);
*2000;
%jorm (G1527, 
	   G1543 G1548 G1553 G1558 G1563 G1568 G1573 G1578 G1583 G1588 G1593 G1598 G1602 G1605 G1608 G1611, 
	   G1544 G1549 G1554 G1559 G1564 G1569 G1574 G1579 G1584 G1589 G1594 G1599 G1603 G1606 G1609 G1612,
       G1545 G1550 G1555 G1560 G1565 G1570 G1575 G1580 G1585 G1590 G1595 G1600 G1604 G1607 G1610 G1613,
	   G1543, 00, h00pc_r);
*2002;
%jorm (HD501,
	   HD506 HD509 HD512 HD515 HD518 HD521 HD524 HD527 HD530 HD533 HD536 HD539 HD542 HD545 HD548 HD551, 
	   HD507 HD510 HD513 HD516 HD519 HD522 HD525 HD528 HD531 HD534 HD537 HD540 HD543 HD546 HD549 HD552,
       HD508 HD511 HD514 HD517 HD520 HD523 HD526 HD529 HD532 HD535 HD538 HD541 HD544 HD547 HD550 HD553,
	   HD506, 02, h02d_r);
*2004;
%jorm (JD501,
	   JD506 JD509 JD512 JD515 JD518 JD521 JD524 JD527 JD530 JD533 JD536 JD539 JD542 JD545 JD548 JD551, 
	   JD507 JD510 JD513 JD516 JD519 JD522 JD525 JD528 JD531 JD534 JD537 JD540 JD543 JD546 JD549 JD552,
       JD508 JD511 JD514 JD517 JD520 JD523 JD526 JD529 JD532 JD535 JD538 JD541 JD544 JD547 JD550 JD553,
	   JD506, 04, h04d_r);
*2006;
%jorm (KD501,
	   KD506 KD509 KD512 KD515 KD518 KD521 KD524 KD527 KD530 KD533 KD536 KD539 KD542 KD545 KD548 KD551, 
	   KD507 KD510 KD513 KD516 KD519 KD522 KD525 KD528 KD531 KD534 KD537 KD540 KD543 KD546 KD549 KD552,
       KD508 KD511 KD514 KD517 KD520 KD523 KD526 KD529 KD532 KD535 KD538 KD541 KD544 KD547 KD550 KD553,
	   KD506, 06, h06d_r);
*2008;
%jorm (LD501,
	   LD506 LD509 LD512 LD515 LD518 LD521 LD524 LD527 LD530 LD533 LD536 LD539 LD542 LD545 LD548 LD551, 
	   LD507 LD510 LD513 LD516 LD519 LD522 LD525 LD528 LD531 LD534 LD537 LD540 LD543 LD546 LD549 LD552,
       LD508 LD511 LD514 LD517 LD520 LD523 LD526 LD529 LD532 LD535 LD538 LD541 LD544 LD547 LD550 LD553,
	   LD506, 08, h08d_r);
*2010;
%jorm (MD501,
	   MD506 MD509 MD512 MD515 MD518 MD521 MD524 MD527 MD530 MD533 MD536 MD539 MD542 MD545 MD548 MD551, 
	   MD507 MD510 MD513 MD516 MD519 MD522 MD525 MD528 MD531 MD534 MD537 MD540 MD543 MD546 MD549 MD552,
       MD508 MD511 MD514 MD517 MD520 MD523 MD526 MD529 MD532 MD535 MD538 MD541 MD544 MD547 MD550 MD553,
	   MD506, 10, h10d_r);
*2012;
%jorm (ND501,
	   ND506 ND509 ND512 ND515 ND518 ND521 ND524 ND527 ND530 ND533 ND536 ND539 ND542 ND545 ND548 ND551, 
	   ND507 ND510 ND513 ND516 ND519 ND522 ND525 ND528 ND531 ND534 ND537 ND540 ND543 ND546 ND549 ND552,
       ND508 ND511 ND514 ND517 ND520 ND523 ND526 ND529 ND532 ND535 ND538 ND541 ND544 ND547 ND550 ND553,
	   ND506, 12, h12d_r);
*2014;
%jorm (OD501,
	   OD506 OD509 OD512 OD515 OD518 OD521 OD524 OD527 OD530 OD533 OD536 OD539 OD542 OD545 OD548 OD551, 
	   OD507 OD510 OD513 OD516 OD519 OD522 OD525 OD528 OD531 OD534 OD537 OD540 OD543 OD546 OD549 OD552,
       OD508 OD511 OD514 OD517 OD520 OD523 OD526 OD529 OD532 OD535 OD538 OD541 OD544 OD547 OD550 OD553,
	   OD506, 14, h14d_r);
	
/***************************************************************************************
Other proxy-cognition variables from HRS core files
	- Jorm symptoms (out of 5)
	- interviewer assessment (NOT USED)
************************************************************************************/
*Jorm symptoms;
%macro cjorm(y, raw, lost, wander, alone, halluc, mem); 
data wave_&y; 
	set raw.&raw (keep = hhid pn &lost &wander &alone &halluc &mem);

	if &lost = 1 then lost_&y = 1; else if &lost = 5 then lost_&y = 0;
	if &wander = 1 then wander_&y = 1; else if &wander = 5 then wander_&y = 0; /*if = 4 (R cannot wander off), count as missing*/
	if &alone = 5 then alone_&y = 1; else if &alone = 1 then alone_&y = 0; /*it is a symptom if R CANNOT be left alone; not a symptom if ok to be left alone*/
	if &halluc = 1 then hallucinate_&y = 1; else if &halluc = 5 then hallucinate_&y = 0;
	if &mem = 5 then memsymp_&y = 1; else if &mem in (1, 2, 3, 4) then memsymp_&y = 0;

	jormsymp5_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y);
	label jormsymp5_&y = "Total number of Jorm symptoms out of 5: lost, wandering, left alone, hallucinate, memory, y&y";

	proc sort; by hhid pn;
run;

data base;
	merge base wave_&y (keep = hhid pn jormsymp5_&y);
	by hhid pn;
/*	proc means; var pr_memsc5_&y IQCODE5_&y jormsymp5_&y;*/
run;
%mend;
*1994 - only available for AHEAD cohort - intvw in 1993, change suffix to 1994;
%cjorm(93, br21, V342, V343, V344, V345, V323); 
data base; set base;
	rename jormsymp5_93 = jormsymp5_94;
	proc means nolabels; var jormsymp5_94;
run;
*wave 3 interviewed in different years for AHEAD and HRS - combine both to suffix 1996;
%cjorm(95, a95pc_r, D1144, D1145, D1146, D1147, D1056); 
%cjorm(96, h96pc_r, E1144, E1145, E1146, E1147, E1056);
proc means data=base; var jormsymp5_95 jormsymp5_96; run;
data base; set base;
	if jormsymp5_96 = . then jormsymp5_96 = jormsymp5_95;
	proc means nolabels; var jormsymp5_95 jormsymp5_96;
	where hacohort in (0, 1);
run;
data base; set base (drop = jormsymp5_95); run;
%cjorm(98, h98pc_r, F1461, F1462, F1463, F1464, F1373)
%cjorm(00, h00pc_r, G1615, G1616, G1617, G1618, G1527)
%cjorm(02, h02d_r, HD554, HD555, HD556, HD557, HD501)
%cjorm(04, h04d_r, JD554, JD555, JD556, JD557, JD501)
%cjorm(06, h06d_r, KD554, KD555, KD556, KD557, KD501)
%cjorm(08, h08d_r, LD554, LD555, LD556, LD557, LD501)
%cjorm(10, h10d_r, MD554, MD555, MD556, MD557, MD501)
%cjorm(12, h12d_r, ND554, ND555, ND556, ND557, ND501); 
%cjorm(14, h14d_r, OD554, OD555, OD556, OD557, OD501); 


/***************************************************************************************
Social engagement variables from HRS core files (changes variables not used, star in 1998)
	- volunteering
	- helping friends, neighbors others

	- Code help others as yes no;
	- Code volunteering and help others as 3 level: 0=no, 1=1-99 hrs, 2=100-199 hrs, 3=200+ hrs

************************************************************************************/
*1998 and 2000;
%macro ext(y, raw, vyn, vhr, v100, v200, hhr, h100, h200);
data wave_&y;
	set raw.&raw (keep = hhid pn &vyn &vhr &v100 &v200 &hhr &h100 &h200);

	*volunteering;
	if &vyn = 1 then do;
		volunteeryn_&y = 1;
		if 0 le &vhr le 9000 then volunteerhrs_&y = (&vhr > 0) + (&vhr > 99) + (&vhr > 199);
		else do;
			if &v100 = 1 then volunteerhrs_&y = 1;
			else if &v100 = 3 then volunteerhrs_&y = 2;
			else if &v100 = 5 then do;
				if &v200 = 1 then volunteerhrs_&y = 2;
				else if &v200 in (3, 5) then volunteerhrs_&y = 3;
				else volunteerhrs_&y = 2; /*if responded more than 100 hrs, but did not to respond to less or more than 200, set to 2 (100-199 hrs)*/
			end;
		end;
	end;
	else if &vyn = 5 then do;
		volunteeryn_&y = 0;
		volunteerhrs_&y = 0;
	end;
	if &vhr = 0 then volunteeryn_&y = 0; *override volunteerYN with 0 if responded yes to volunteering, but 0 hrs;

	*helping others;
	if &hhr = 0 then helpothershrs_&y = 0;
	else if 1 le &hhr le 9000 then helpothershrs_&y = 1 + (&hhr > 99) + (&hhr > 199);
	else do;
		if &h100 = 1 then helpothershrs_&y = 1;
		else if &h100 = 3 then helpothershrs_&y = 2;
		else if &h100 = 5 then do;
			if &h200 = 1 then helpothershrs_&y = 2;
			else if &h200 in (3, 5) then helpothershrs_&y = 3;
			else helpothershrs_&y = 2;/*if responded more than 100 hrs, but did not to respond to less or more than 200, set to 2 (100-199 hrs)*/
		end;
	end;
	if helpothershrs_&y = 0 then helpothersyn_&y = 0;
	else if helpothershrs_&y in (1, 2, 3) then helpothersyn_&y = 1;

	proc freq; tables volunteeryn_&y volunteerhrs_&y helpothersyn_&y helpothershrs_&y;
run;

data base;
	merge base wave_&y (keep = hhid pn volunteeryn_&y volunteerhrs_&y helpothersyn_&y helpothershrs_&y);
	by hhid pn;

	label volunteeryn_&y = "spent any time volunteering in past year, wave &y";
	label volunteerhrs_&y = "hours spent voluntering in past year (0=0, 1=1-99, 2=100-199, 3=200+), wave &y";
	label helpothersyn_&y = "spent any time helping others in past year, wave &y";
	label helpothershrs_&y = "hours spent helping others in past year (0=0, 1=1-99, 2=100-199, 3=200+), wave &y";
run;
%mend;
%ext(98, h98e_r, F2677, F2678, F2679, F2680, F2681, F2682, F2683)
%ext(00, h00e_r, G2995, G2996, G2997, G2998, G2999, G3000, G3001)

*2002;
data wave_02; set raw.h02g_r (keep = hhid pn HG086 HG087 HG089 HG090 HG092 HG094 HG095);
	*volunteering;
	if HG086 = 1 then do;
		volunteeryn_02 = 1;
		if 0 le HG087 le 9000 then volunteerhrs_02 = (HG087 > 0) + (HG087 > 99) + (HG087 > 199);
		else do;
			if HG089 = 0 and HG090 = 99 then volunteerhrs_02 = 1;
			else if HG089 in (100, 101) and HG090 in (100, 199) then volunteerhrs_02 = 2;
			else if HG089 in (200, 201) and HG090 in (200, 2000) then volunteerhrs_02 = 3;
		end;
	end;
	else if HG086 = 5 then do;
		volunteeryn_02 = 0;
		volunteerhrs_02 = 0;
	end;
	if HG087 = 0 then volunteeryn_02 = 0; *override volunteerYN with 0 if responded yes to volunteering, but 0 hrs;

	*help others;
	if 0 le HG092 le 9000 then helpothershrs_02 = (HG092 > 0) + (HG092 > 99) + (HG092 > 199);
	else do;
		if HG094 = 0 and HG095 = 99 then helpothershrs_02 = 1;
		else if HG094 in (100, 101) and HG095 in (100, 199) then helpothershrs_02 = 2;
		else if HG094 in (200, 201) and HG095 in (200, 2000) then helpothershrs_02 = 3;
	end;
	if helpothershrs_02 = 0 then helpothersyn_02 = 0; 
	else if helpothershrs_02 in (1, 2, 3) then helpothersyn_02 = 1;

	proc sort; by hhid pn;
run;
data base;
	merge base wave_02 (keep = hhid pn volunteeryn_02 volunteerhrs_02 helpothersyn_02 helpothershrs_02);
	by hhid pn;

	label volunteeryn_02 = "spent any time volunteering in past year, wave 02";
	label volunteerhrs_02 = "hours spent voluntering in past year (0=0, 1=1-99, 2=100-199, 3=200+), wave 02";
	label helpothersyn_02 = "spent any time helping others in past year, wave 02";
	label helpothershrs_02 = "hours spent helping others in past year (0=0, 1=1-99, 2=100-199, 3=200+), wave 02";
run;

*2004-2014;
%macro ext(y, raw, vyn, v100, v200, hyn, h100, h200);
data wave_&y; 
	set raw.&raw (keep = hhid pn &vyn &v100 &v200 &hyn &h100 &h200);

	*volunteering;
	if &vyn = 1 then do;
		volunteeryn_&y = 1;
		
		if &v100 = 1 then volunteerhrs_&y = 1;
		else if &v100 = 3 then volunteerhrs_&y = 2;
		else if &v100 = 5 then do;
			if &v200 = 1 then volunteerhrs_&y = 2;
			else if &v200 in (3, 5) then volunteerhrs_&y = 3;
		end;
	end;
	else if &vyn = 5 then do;
		volunteeryn_&y = 0;
		volunteerhrs_&y = 0;
	end;

	*help others;
	if &hyn = 1 then do;
		helpothersyn_&y = 1;
		
		if &h100 = 1 then helpothershrs_&y = 1;
		else if &h100 = 3 then helpothershrs_&y = 2;
		else if &h100 = 5 then do;
			if &h200 = 1 then helpothershrs_&y = 2;
			else if &h200 in (3, 5) then helpothershrs_&y = 3;
		end;
	end;
	else if &hyn = 5 then do;
		helpothersyn_&y = 0;
		helpothershrs_&y = 0;
	end;

	proc sort; by hhid pn;
run;

data base;
	merge base wave_&y (keep = hhid pn volunteeryn_&y volunteerhrs_&y helpothersyn_&y helpothershrs_&y);
	by hhid pn;

	label volunteeryn_&y = "spent any time volunteering in past year, wave &y";
	label volunteerhrs_&y = "hours spent voluntering in past year (0=0, 1=1-99, 2=100-199, 3=200+), wave &y";
	label helpothersyn_&y = "spent any time helping others in past year, wave &y";
	label helpothershrs_&y = "hours spent helping others in past year (0=0, 1=1-99, 2=100-199, 3=200+), wave &y";

	proc freq; tables volunteeryn_&y volunteerhrs_&y helpothersyn_&y helpothershrs_&y;
run;
%mend;
%ext(04, h04g_r, JG086, JG195, JG196, JG198, JG199, JG200)
%ext(06, h06g_r, KG086, KG195, KG196, KG198, KG199, KG200)
%ext(08, h08g_r, LG086, LG195, LG196, LG198, LG199, LG200)
%ext(10, h10g_r, MG086, MG195, MG196, MG198, MG199, MG200)
%ext(12, h12g_r, NG086, NG195, NG196, NG198, NG199, NG200)
%ext(14, h14g_r, OG086, OG195, OG196, OG198, OG199, OG200)


/*Create composite social engagement scores*/
%macro soc(y);
data base; set base;
	socialeng7_&y = partnerpres_&y + volunteerhrs_&y + helpothershrs_&y;
		label socialeng7_&y = "Social engagement summary (0-7), 1pt partnered + 0-3 volunteer_hrs + 0-3 helpothershrs, wave &y";

	if socialeng7_&y in (0, 1) then socialeng_d_&y = 1; 
	else if socialeng7_&y NE . then socialeng_d_&y = 0;
		label socialeng_d_&y = "Social engagement binary 1=0 or 1 pts in socialeng7; 0 = 2+ pts in socialeng7, wave &y";

	proc freq; tables socialeng7_&y socialeng_d_&y ;
run;
%mend;
%soc(98) %soc(00) %soc(02) %soc(04) %soc(06)
%soc(08) %soc(10) %soc(12) %soc(14)

/****************************************************************************
* Create standardized change in IADLs (for ML model)
*****************************************************************************/

%macro ch(v);
	/*create _ch version (ignore number waves skipped) first*/
	data base; set base;
		*1998 (w4);
		if randchf_98 = 0 then &v._sdch2_98 = &v._98 - &v._96;
		else if randchf_98 = 1 then &v._sdch2_98 = (&v._98 - &v._94)/2;
		*2000 (w5);
		if randchf_00 = 0 then &v._sdch2_00 = &v._00 - &v._98;
		else if randchf_00 = 1 then &v._sdch2_00 = (&v._00 - &v._96)/2;
		else if randchf_00 = 2 then &v._sdch2_00 = (&v._00 - &v._94)/3;
		*2002 (w6);
		if randchf_02 = 0 then &v._sdch2_02 = &v._02 - &v._00;
		else if randchf_02 = 1 then &v._sdch2_02 = (&v._02 - &v._98)/2;
		else if randchf_02 = 2 then &v._sdch2_02 = (&v._02 - &v._96)/3;
		*2004 (w7);
		if randchf_04 = 0 then &v._sdch2_04 = &v._04 - &v._02;
		else if randchf_04 = 1 then &v._sdch2_04 = (&v._04 - &v._00)/2;
		else if randchf_04 = 2 then &v._sdch2_04 = (&v._04 - &v._98)/3;
		*2006 (w8);
		if randchf_06 = 0 then &v._sdch2_06 = &v._06 - &v._04;		
		else if randchf_06 = 1 then &v._sdch2_06 = (&v._06 - &v._02)/2;		
		else if randchf_06 = 2 then &v._sdch2_06 = (&v._06 - &v._00)/3;		
		*2008 (w9);
		if randchf_08 = 0 then &v._sdch2_08 = &v._08 - &v._06;		
		else if randchf_08 = 1 then &v._sdch2_08 = (&v._08 - &v._04)/2;		
		else if randchf_08 = 2 then &v._sdch2_08 = (&v._08 - &v._02)/3;		
		*2010 (w10);
		if randchf_10 = 0 then &v._sdch2_10 = &v._10 - &v._08;		
		else if randchf_10 = 1 then &v._sdch2_10 = (&v._10 - &v._06)/2;		
		else if randchf_10 = 2 then &v._sdch2_10 = (&v._10 - &v._04)/3;		
		*2012 (w11);
		if randchf_12 = 0 then &v._sdch2_12 = &v._12 - &v._10;
		else if randchf_12 = 1 then &v._sdch2_12 = (&v._12 - &v._08)/2;
		else if randchf_12 = 2 then &v._sdch2_12 = (&v._12 - &v._06)/3;
		*2014 (w12);
		if randchf_14 = 0 then &v._sdch2_14 = &v._14 - &v._12;
		else if randchf_14 = 1 then &v._sdch2_14 = (&v._14 - &v._10)/2;
		else if randchf_14 = 2 then &v._sdch2_14 = (&v._14 - &v._08)/3;

		proc means nolabels; var &v._98 &v._sdch2_98  &v._04 &v._sdch2_04  &v._08 &v._sdch2_08 &v._10 &v._sdch2_10 &v._14 &v._sdch2_14;
	run;
%mend;
%ch(iadl) 

/**************************************************************************************
*	consruct change variables for Hurd
*		- non-standardized - go back as many waves as necessary
*			- same as coding used for re-estimating Hurd from comparison paper
**************************************************************************************/
%macro ch(v);
	data base; set base;
	/*1998 (w4)*/
		if &v._96 NE . then &v.ch_98 = &v._98 - &v._96; 
		else if &v._94 NE . then &v.ch_98 = &v._98 - &v._94; 
		label &v.ch_98 = "change in &v between last non-missing interview and 1998 (non-standardized, no lookback limit)";

	/*2000 (w5)*/
		if &v._98 NE . then &v.ch_00 = &v._00 - &v._98; 
		else if &v._96 NE . then &v.ch_00 = &v._00 - &v._96; 
		else if &v._94 NE . then &v.ch_00 = &v._00 - &v._94; 
		label &v.ch_00 = "change in &v between last non-missing interview and 2000 (non-standardized, no lookback limit)";

	/*2002 (w6)*/
		if &v._00 NE . then &v.ch_02 = &v._02 - &v._00; 
		else if &v._98 NE . then &v.ch_02 = &v._02 - &v._98; 
		else if &v._96 NE . then &v.ch_02 = &v._02 - &v._96; 
		else if &v._94 NE . then &v.ch_02 = &v._02 - &v._94; 
		label &v.ch_02 = "change in &v between last non-missing interview and 2002 (non-standardized, no lookback limit)";

	/*2004 (w7)*/
		if &v._02 NE . then &v.ch_04 = &v._04 - &v._02; 
		else if &v._00 NE . then &v.ch_04 = &v._04 - &v._00; 
		else if &v._98 NE . then &v.ch_04 = &v._04 - &v._98; 
		else if &v._96 NE . then &v.ch_04 = &v._04 - &v._96; 
		else if &v._94 NE . then &v.ch_04 = &v._04 - &v._94; 
		label &v.ch_04 = "change in &v between last non-missing interview and 2004 (non-standardized, no lookback limit)";

	/*2006 (w8)*/
		if &v._04 NE . then &v.ch_06 = &v._06 - &v._04; 
		else if &v._02 NE . then &v.ch_06 = &v._06 - &v._02; 
		else if &v._00 NE . then &v.ch_06 = &v._06 - &v._00; 
		else if &v._98 NE . then &v.ch_06 = &v._06 - &v._98; 
		else if &v._96 NE . then &v.ch_06 = &v._06 - &v._96; 
		else if &v._94 NE . then &v.ch_06 = &v._06 - &v._94; 
		label &v.ch_06 = "change in &v between last non-missing interview and 2006 (non-standardized, no lookback limit)";

	/*2008 (w9)*/
		if &v._06 NE . then &v.ch_08 = &v._08 - &v._06; 
		else if &v._04 NE . then &v.ch_08 = &v._08 - &v._04; 
		else if &v._02 NE . then &v.ch_08 = &v._08 - &v._02; 
		else if &v._00 NE . then &v.ch_08 = &v._08 - &v._00; 
		else if &v._98 NE . then &v.ch_08 = &v._08 - &v._98; 
		else if &v._96 NE . then &v.ch_08 = &v._08 - &v._96; 
		else if &v._94 NE . then &v.ch_08 = &v._08 - &v._94;
		label &v.ch_08 = "change in &v between last non-missing interview and 2008 (non-standardized, no lookback limit)";

 	/*2010 (w10)*/
		if &v._08 NE . then &v.ch_10 = &v._10 - &v._08; 
		else if &v._06 NE . then &v.ch_10 = &v._10 - &v._06; 
		else if &v._04 NE . then &v.ch_10 = &v._10 - &v._04; 
		else if &v._02 NE . then &v.ch_10 = &v._10 - &v._02; 
		else if &v._00 NE . then &v.ch_10 = &v._10 - &v._00; 
		else if &v._98 NE . then &v.ch_10 = &v._10 - &v._98; 
		else if &v._96 NE . then &v.ch_10 = &v._10 - &v._96; 
		else if &v._94 NE . then &v.ch_10 = &v._10 - &v._94;
		label &v.ch_10 = "change in &v between last non-missing interview and 2010 (non-standardized, no lookback limit)";

 	/*2012 (w11)*/
		if &v._10 NE . then &v.ch_12 = &v._12 - &v._10; 
		else if &v._08 NE . then &v.ch_12 = &v._12 - &v._08; 
		else if &v._06 NE . then &v.ch_12 = &v._12 - &v._06; 
		else if &v._04 NE . then &v.ch_12 = &v._12 - &v._04; 
		else if &v._02 NE . then &v.ch_12 = &v._12 - &v._02; 
		else if &v._00 NE . then &v.ch_12 = &v._12 - &v._00; 
		else if &v._98 NE . then &v.ch_12 = &v._12 - &v._98; 
		else if &v._96 NE . then &v.ch_12 = &v._12 - &v._96; 
		else if &v._94 NE . then &v.ch_12 = &v._12 - &v._94;
		label &v.ch_12 = "change in &v between last non-missing interview and 2012 (non-standardized, no lookback limit)";

 	/*2014 (w12)*/
		if &v._12 NE . then &v.ch_14 = &v._14 - &v._12; 
		else if &v._10 NE . then &v.ch_14 = &v._14 - &v._10; 
		else if &v._08 NE . then &v.ch_14 = &v._14 - &v._08; 
		else if &v._06 NE . then &v.ch_14 = &v._14 - &v._06; 
		else if &v._04 NE . then &v.ch_14 = &v._14 - &v._04; 
		else if &v._02 NE . then &v.ch_14 = &v._14 - &v._02; 
		else if &v._00 NE . then &v.ch_14 = &v._14 - &v._00; 
		else if &v._98 NE . then &v.ch_14 = &v._14 - &v._98; 
		else if &v._96 NE . then &v.ch_14 = &v._14 - &v._96; 
		else if &v._94 NE . then &v.ch_14 = &v._14 - &v._94;
		label &v.ch_14 = "change in &v between last non-missing interview and 2014 (non-standardized, no lookback limit)";

		proc means nolabels; var &v.ch_98 &v.ch_00 &v.ch_02 &v.ch_04 &v.ch_06 &v.ch_08 &v.ch_10 &v.ch_12 &v.ch_14;

	run;
%mend;
%ch(iadl) /*adl already constructed by RAND*/
%ch(date_recall) 
%ch(bwc1) 
%ch(ser7) 
%ch(scis) %ch(cact)
%ch(pres) /*VP not used in Hurd*/
%ch(iword) %ch(dword)

/**************************************************************************************
*	consruct change in IQCODE for Hurd
*		- following logic from previous paper: lookback 1 wave
*		- then impute any missing change variables if necessary using LOCF
**************************************************************************************/
%macro ch(y, yb);
data base; set base;
	IQCODEch_&y = IQCODE_&y - IQCODE_&yb;
	label IQCODEch_&y = "Jorm IQCODE change between past 2 waves for Hurd, wave &y";
	proc means nolabels; var IQCODE_&y IQCODEch_&y; 
run;
%mend;
%ch(14, 12) %ch(12, 10) %ch(10, 08) %ch(08, 06) %ch(06, 04) %ch(04, 02) %ch(02, 00)
%ch(00, 98) %ch(98, 96)


/******************************************************************************************************************************
* Impute missing values for proxy-cognitino using LOCF (as per Wu)
*	- create SECOND version of variable for ease of use if we want to subset to non-imputed values
*	- Also create flag to count Ns of imputed values
******************************************************************************************************************************/
%macro imp(var);
data base; set base;
	array prior[*] &var._94 &var._96 &var._98 &var._00 &var._02 &var._04 &var._06 &var._08 &var._10 &var._12;
	array var[*] &var._96 &var._98 &var._00 &var._02 &var._04 &var._06 &var._08 &var._10 &var._12 &var._14;
	array imp[*] &var._i_96 &var._i_98 &var._i_00 &var._i_02 &var._i_04 &var._i_06 &var._i_08 &var._i_10 &var._i_12 &var._i_14;
	array flag[*] &var._if_96 &var._if_98 &var._if_00 &var._if_02 &var._if_04 &var._if_06 &var._if_08 &var._if_10 &var._if_12 &var._if_14;
	array proxy[*] proxy_96 proxy_98 proxy_00 proxy_02 proxy_04 proxy_06 proxy_08 proxy_10 proxy_12 proxy_14;

	do i = 1 to 10;
		if proxy[i] = 1 then do;
			if var[i] = . and prior[i] NE . then do;
				imp[i] = prior[i];
				flag[i] = 1;
			end;
			else do;
				imp[i] = var[i];
				flag[i] = 0;
			end;
		end;
	end;

	*for 1994 wave (where there is no prior wave), set imputed version equal to non-imputed version for all;
	&var._i_94 = &var._94;

	proc means nolabels;
		var &var._94 &var._i_94 &var._96 &var._i_96 &var._if_96 &var._98 &var._i_98 &var._if_98 &var._00 &var._i_00 &var._if_00 &var._02 &var._i_02 &var._if_02 
			&var._04 &var._i_04 &var._if_04 &var._06 &var._i_06 &var._if_06 &var._08 &var._i_08 &var._if_08 &var._10 &var._i_10 &var._if_10
			&var._12 &var._i_12 &var._if_12 &var._14 &var._i_14 &var._if_14;
run;
%mend;

/*proc print data=base (obs=100);*/
/*var hhid pn IQCODEch_00 IQCODEch_i_00 IQCODEch_if_00 IQCODEch_00 IQCODEch_98 proxy_00; run;*/

%imp(IQCODE5) %imp(pr_memsc5) %imp(jormsymp5)  %imp(IQCODE) %imp(IQCODEch)

*label new variables;
%macro lab(y);
data base; set base;
	label IQCODE5_i_&y = "IQCODE5 with LOCF imputations for missing values, wave &y";
	label IQCODE5_if_&y = "IQCODE5 LOCF imputation flag , wave &y";
	label IQCODE_i_&y = "IQCODE (for Hurd) with LOCF imputations for missing values, wave &y";
	label IQCODEch_if_&y = "change in IQCODE (for Hurd) LOCF imputation flag , wave &y";
	label pr_memsc5_i_&y = "pr_memsc5 with LOCF imputations for missing values, wave &y";
	label pr_memsc5_if_&y = "pr_memsc5 LOCF imputation flag , wave &y";
	label jormsymp5_i_&y = "jormsymp5 with LOCF imputations for missing values, wave &y";
	label jormsymp5_if_&y = "jormsymp5 LOCF imputation flag , wave &y";
run;
%mend;
%lab(96) %lab(98) %lab(00) %lab(02) %lab(04) %lab(06) %lab(08) %lab(10) %lab(12) %lab(14)

/**************************************************************************************
*	Set up Hurd lag variables (self-cognition 2 waves prior for proxy-self)
*		- limit 1 lookback period, as per data cleaning rules for training dataset
**************************************************************************************/

%macro lag (c, b); 
data base; set base;
	if proxy_&c = 1 then do;
		if proxy_&b = 1 then do;
			proxy_lag_&c = 1; label proxy_lag_&c = "PRIOR wave proxy responent status (for proxy respondents only), wave &c";
			date_recall_lag_&c = 0; label date_recall_lag_&c = "PRIOR wave Hurd dates test (0-4) (for proxy respondents only), wave &c";
			ser7_lag_&c = 0; label ser7_lag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), wave &c";
			pres_lag_&c = 0; label pres_lag_&c = "PRIOR wave TICS president recall: 0-1 (for proxy respondents only), wave &c";
			iword_lag_&c = 0; label iword_lag_&c = "PRIOR wave TICS iword: 0-10 (for proxy respondents only), wave &c";
			dword_lag_&c = 0; label dword_lag_&c = "PRIOR wave TICS dword 7: 0-10 (for proxy respondents only), wave &c";
			*keep iqcodech as is;
		end;

		else if proxy_&b = 0 then do;
			proxy_lag_&c = 0;
			date_recall_lag_&c = date_recall_&b;
			ser7_lag_&c = ser7_&b;
			pres_lag_&c = pres_&b;
			iword_lag_&c = iword_&b;
			dword_lag_&c = dword_&b;
			iqcodech_i_&c = 0;
		end;
	end;
run;

proc means nolabels; var proxy_lag_&c date_recall_lag_&c ser7_lag_&c pres_lag_&c iword_lag_&c dword_lag_&c iqcodech_i_&c; where proxy_&c = 1 and proxy_&b = 1; run;
proc means nolabels; var proxy_lag_&c date_recall_lag_&c ser7_lag_&c pres_lag_&c iword_lag_&c dword_lag_&c iqcodech_i_&c; where proxy_&c = 1 and proxy_&b = 0; run;

%mend;
%lag(98, 96) %lag(00, 98) %lag(02, 00) %lag(04, 02) %lag(06, 04)
%lag(08, 06) %lag(10, 08) %lag(12, 10) %lag(14, 12);

/******************************************************************************************************************************
* Create proxy indicators, standardized change/lagged cognition variables
*	Go back to last wave with participation (use rand flag variable)
*		***4 CATEGORIES (create dummies)***
*			1. Current-self & Last-self
*				Compute change in self-cognition variables
*			2. Current-self & Last-proxy
*				Go back further and identify last wave with self-participation and compute change
*				NOTE; this is still a different category from first – i.e. different dummy indicator
*				Check N of observations with only proxy waves prior to current self-waves, where this approach would not work
*			3. Current-proxy & Last-proxy
*				Compute change in proxy-cognition variables (except interviewer cognition due to lack of data availability)
*			4. Current-proxy & Last-self
*				Create lag self-response variables 
*
*	LIMIT ALL TO MISSING 2 WAVES ONLY (use _sdch2 sufix for consistency)
* 
* Variablse
*	self-cognition: iword, iwordsq, dword, dword_m, tics13, tics13sq, ticsmo_&y, ticsdt_&y, ticsyr_&y, ticswk_&y, cact_&y, scis_&ym pres_&y, vp_&y, ser7_&y, bwc_&y
*		- compute change for groups 1 and 2
*		- take lagged wave for group 4
*	proxy-proxy change: IQCODE5, IQCODE5_m, pr_memsc5, jormsymp5
*		- compute change for group 3
*******************************************************************************************************************************/
%macro ch(y, sk, b);
	data base; set base;
		if randchf_&y = &sk then do;
		****group1 - current self and last self;
			if proxy_&y = 0 and proxy_&b = 0 then do;
				*set indicators;
					cself_lself2_&y = 1;
					cself_lproxy2_&y = 0;
					cproxy_lproxy2_&y = 0;
					cproxy_lself2_&y = 0;

				*compute self-change;
					iword_sdch2_&y = (iword_&y - iword_&b)/(&sk+1);
					iwordsq_sdch2_&y = (iwordsq_&y - iwordsq_&b)/(&sk+1);
					dword_sdch2_&y = (dword_&y - dword_&b)/(&sk+1);
					tics13_sdch2_&y = (tics13_&y - tics13_&b)/(&sk+1);
					tics13sq_sdch2_&y = (tics13sq_&y - tics13sq_&b)/(&sk+1);
					date_wrong_sdch2_&y = (date_wrong_&y - date_wrong_&b)/(&sk+1);
					name_wrong_sdch2_&y = (name_wrong_&y - name_wrong_&b)/(&sk+1);
					ser7_sdch2_&y = (ser7_&y - ser7_&b)/(&sk+1);
					bwc_sdch2_&y = (bwc_&y - bwc_&b)/(&sk+1);

				*set proxy-change to 0;
					IQCODE5_i_sdch2_&y = 0;
					pr_memsc5_i_sdch2_&y = 0;
					jormsymp5_i_sdch2_&y = 0;

				*set laggedself (for proxies) to 0;
					iword_lag2_&y = 0;
					iwordsq_lag2_&y = 0;
					dword_lag2_&y = 0;
					tics13_lag2_&y = 0;
					tics13sq_lag2_&y = 0;
					date_wrong_lag2_&y = 0;
					name_wrong_lag2_&y = 0;
					ser7_lag2_&y = 0;
					bwc_lag2_&y = 0;
			end;

		****group2 - current self and last proxy;
			if proxy_&y = 0 and proxy_&b = 1 then do;
				*set indicators;
					cself_lself2_&y = 0;
					cself_lproxy2_&y = 1;
					cproxy_lproxy2_&y = 0;
					cproxy_lself2_&y = 0;
					
				*for self-change: need to go back to last available self prior to proxy - NEXT MACRO

				*set proxy-change to 0;
					IQCODE5_i_sdch2_&y = 0;
					pr_memsc5_i_sdch2_&y = 0;
					jormsymp5_i_sdch2_&y = 0;

				*set laggedself (for proxies) to 0;
					iword_lag2_&y = 0;
					iwordsq_lag2_&y = 0;
					dword_lag2_&y = 0;
					tics13_lag2_&y = 0;
					tics13sq_lag2_&y = 0;
					date_wrong_lag2_&y = 0;
					name_wrong_lag2_&y = 0;
					ser7_lag2_&y = 0;
					bwc_lag2_&y = 0;
			end;

		****group3 - current proxy and last proxy;
			if proxy_&y = 1 and proxy_&b = 1 then do;
				*set indicators;
					cself_lself2_&y = 0;
					cself_lproxy2_&y = 0;
					cproxy_lproxy2_&y = 1;
					cproxy_lself2_&y = 0;
					
				*compute proxy change;
					IQCODE5_i_sdch2_&y = (IQCODE5_i_&y - IQCODE5_i_&b)/(&sk + 1);
					pr_memsc5_i_sdch2_&y = (pr_memsc5_i_&y - pr_memsc5_i_&b)/(&sk + 1);
					jormsymp5_i_sdch2_&y = (jormsymp5_i_&y - jormsymp5_i_&b)/(&sk + 1);

				*set self-change to 0;
					iword_sdch2_&y = 0;
					iwordsq_sdch2_&y = 0;
					dword_sdch2_&y = 0;
					tics13_sdch2_&y = 0;
					tics13sq_sdch2_&y = 0;
					date_wrong_sdch2_&y = 0;
					name_wrong_sdch2_&y = 0;
					ser7_sdch2_&y = 0;
					bwc_sdch2_&y = 0;

				*set laggedself (for proxies) to 0;
					iword_lag2_&y = 0;
					iwordsq_lag2_&y = 0;
					dword_lag2_&y = 0;
					tics13_lag2_&y = 0;
					tics13sq_lag2_&y = 0;
					date_wrong_lag2_&y = 0;
					name_wrong_lag2_&y = 0;
					ser7_lag2_&y = 0;
					bwc_lag2_&y = 0;
			end;

		****group4 - current proxy and last self;
			if proxy_&y = 1 and proxy_&b = 0 then do;
				*set indicators;
					cself_lself2_&y = 0;
					cself_lproxy2_&y = 0;
					cproxy_lproxy2_&y = 0;
					cproxy_lself2_&y = 1;

				*create lagged self-cognition variables;
					iword_lag2_&y = iword_&b;
					iwordsq_lag2_&y = iwordsq_&b;
					dword_lag2_&y = dword_&b;
					tics13_lag2_&y = tics13_&b;
					tics13sq_lag2_&y = tics13sq_&b;
					date_wrong_lag2_&y = date_wrong_&b;
					name_wrong_lag2_&y = name_wrong_&b;
					ser7_lag2_&y = ser7_&b;
					bwc_lag2_&y = bwc_&b;

				*set proxy-change to 0;
					IQCODE5_i_sdch2_&y = 0;
					pr_memsc5_i_sdch2_&y = 0;
					jormsymp5_i_sdch2_&y = 0;

				*set self-change to 0;
					iword_sdch2_&y = 0;
					iwordsq_sdch2_&y = 0;
					dword_sdch2_&y = 0;
					tics13_sdch2_&y = 0;
					tics13sq_sdch2_&y = 0;
					date_wrong_sdch2_&y = 0;
					name_wrong_sdch2_&y = 0;
					ser7_sdch2_&y = 0;
					bwc_sdch2_&y = 0;
			end;
		end;
	run;

	*for those with no waves skipped - should compute change if current wave imputed from last wave, but last wave not imputed;
	%if &sk= 0 %then %do;
		data base; set base;
			if IQCODE5_if_&y = 1 and IQCODE5_if_&b NE 1 then IQCODE5_i_sdch2_&y = .;
			if pr_memsc5_if_&y = 1 and pr_memsc5_if_&b NE 1 then pr_memsc5_i_sdch2_&y = .;
			if jormsymp5_if_&y = 1 and jormsymp5_if_&b NE 1 then jormsymp5_i_sdch2_&y = .;
		run;			
	%end;

	title "check Ns for wave &y and skip waves &sk";
	proc freq data=base;
		tables randchf_&y;
		where hrs_age70_&y > -5;
	run;

	proc means data = base nolabels; 
	var cself_lself2_&y cself_lproxy2_&y cproxy_lproxy2_&y cproxy_lself2_&y 
		iword_sdch2_&y iwordsq_sdch2_&y dword_sdch2_&y tics13_sdch2_&y tics13sq_sdch2_&y name_wrong_sdch2_&y date_wrong_sdch2_&y ser7_sdch2_&y bwc_sdch2_&y
		IQCODE5_i_sdch2_&y pr_memsc5_i_sdch2_&y jormsymp5_i_sdch2_&y 
		iword_lag2_&y iwordsq_lag2_&y dword_lag2_&y tics13_lag2_&y tics13sq_lag2_&y name_wrong_lag2_&y date_wrong_lag2_&y ser7_lag2_&y bwc_lag2_&y;

		where randchf_&y = &sk and hrs_age70_&y > -5;
	run;
 
	title "check categories for wave &y and skip waves &sk";
	proc freq data = base;
		tables cself_lself2_&y cself_lproxy2_&y cproxy_lproxy2_&y cproxy_lself2_&y;
		where randchf_&y = &sk and hrs_age70_&y > -5;
	run;

	title "check means for category 1 (cself-lself) for wave &y and skip waves &sk";
	proc means data = base nolabels; 
	var iword_sdch2_&y iwordsq_sdch2_&y dword_sdch2_&y tics13_sdch2_&y tics13sq_sdch2_&y name_wrong_sdch2_&y date_wrong_sdch2_&y ser7_sdch2_&y bwc_sdch2_&y
		IQCODE5_i_sdch2_&y pr_memsc5_i_sdch2_&y jormsymp5_i_sdch2_&y 
		iword_lag2_&y iwordsq_lag2_&y dword_lag2_&y tics13_lag2_&y tics13sq_lag2_&y name_wrong_lag2_&y date_wrong_lag2_&y ser7_lag2_&y bwc_lag2_&y;
		where randchf_&y = &sk and cself_lself2_&y = 1 and hrs_age70_&y > -5;
	run;

	title "check means for category 2 (cself-lproxy) for wave &y and skip waves &sk - will not have self-change vars yet";
	proc means data = base nolabels; 
	var iword_sdch2_&y iwordsq_sdch2_&y dword_sdch2_&y tics13_sdch2_&y tics13sq_sdch2_&y name_wrong_sdch2_&y date_wrong_sdch2_&y ser7_sdch2_&y bwc_sdch2_&y
		IQCODE5_i_sdch2_&y pr_memsc5_i_sdch2_&y jormsymp5_i_sdch2_&y 
		iword_lag2_&y iwordsq_lag2_&y dword_lag2_&y tics13_lag2_&y tics13sq_lag2_&y name_wrong_lag2_&y date_wrong_lag2_&y ser7_lag2_&y bwc_lag2_&y;
		where randchf_&y = &sk and cself_lproxy2_&y = 1 and hrs_age70_&y > -5;
	run;

	title "check means for category 3 (cproxy-lproxy) for wave &y and skip waves &sk";
	proc means data = base nolabels; 
	var iword_sdch2_&y iwordsq_sdch2_&y dword_sdch2_&y tics13_sdch2_&y tics13sq_sdch2_&y name_wrong_sdch2_&y date_wrong_sdch2_&y ser7_sdch2_&y bwc_sdch2_&y
		IQCODE5_i_sdch2_&y pr_memsc5_i_sdch2_&y jormsymp5_i_sdch2_&y 
		iword_lag2_&y iwordsq_lag2_&y dword_lag2_&y tics13_lag2_&y tics13sq_lag2_&y name_wrong_lag2_&y date_wrong_lag2_&y ser7_lag2_&y bwc_lag2_&y;
		where randchf_&y = &sk and cproxy_lproxy2_&y = 1 and hrs_age70_&y > -5;
	run;

	title "check means for category 4 (cproxy-lself) for wave &y and skip waves &sk";
	proc means data = base nolabels; 
	var iword_sdch2_&y iwordsq_sdch2_&y dword_sdch2_&y tics13_sdch2_&y tics13sq_sdch2_&y name_wrong_sdch2_&y date_wrong_sdch2_&y ser7_sdch2_&y bwc_sdch2_&y
		IQCODE5_i_sdch2_&y pr_memsc5_i_sdch2_&y jormsymp5_i_sdch2_&y 
		iword_lag2_&y iwordsq_lag2_&y dword_lag2_&y tics13_lag2_&y tics13sq_lag2_&y name_wrong_lag2_&y date_wrong_lag2_&y ser7_lag2_&y bwc_lag2_&y;
		where randchf_&y = &sk and cproxy_lself2_&y = 1 and hrs_age70_&y > -5;
	run;
%mend;
*wave 98; %ch(98, 0, 96) %ch(98, 1, 94) 
* IQCODE5 and pr_memsc5 not availale prior to 1996 - affects N=19;
* Not able to go back to randchf = 2 due to data not being available prior to 1994 - only affects N = 12 aged 65+;
*wave 00; %ch(00, 0, 98) %ch(00, 1, 96) %ch(00, 2, 94)
*wave 02; %ch(02, 0, 00) %ch(02, 1, 98) %ch(02, 2, 96) 
*wave 04; %ch(04, 0, 02) %ch(04, 1, 00) %ch(04, 2, 98) 
*wave 06; %ch(06, 0, 04) %ch(06, 1, 02) %ch(06, 2, 00) 
*wave 08; %ch(08, 0, 06) %ch(08, 1, 04) %ch(08, 2, 02) 
*wave 10; %ch(10, 0, 08) %ch(10, 1, 06) %ch(10, 2, 04) 
*wave 12; %ch(12, 0, 10) %ch(12, 1, 08) %ch(12, 2, 06) 
*wave 14; %ch(14, 0, 12) %ch(14, 1, 10) %ch(14, 2, 08) 

/********************************************************************************************************************************************
*Group 2: current self and last proxy
*	- go back further until wave with self (bu no further than 3 waves back)
*		- compute self-change 
*		- create flag for # waves skipped back
*		- no need to check immediate prior wave (already know it's proxy)
*******************************************************************************************************************************************/

%macro ch(y, sk, b);
data base; set base;
	if cself_lproxy2_&y = 1 and proxy_&b = 0 then do;
	*compute self-cognition change;
		iword_sdch2_&y = (iword_&y - iword_&b)/(&sk+1);
		iwordsq_sdch2_&y = (iwordsq_&y - iwordsq_&b)/(&sk+1);
		dword_sdch2_&y = (dword_&y - dword_&b)/(&sk+1);
		tics13_sdch2_&y = (tics13_&y - tics13_&b)/(&sk+1);
		tics13sq_sdch2_&y = (tics13sq_&y - tics13sq_&b)/(&sk+1);
		date_wrong_sdch2_&y = (date_wrong_&y - date_wrong_&b)/(&sk+1);
		name_wrong_sdch2_&y = (name_wrong_&y - name_wrong_&b)/(&sk+1);
		ser7_sdch2_&y = (ser7_&y - ser7_&b)/(&sk+1);
		bwc_sdch2_&y = (bwc_&y - bwc_&b)/(&sk+1);
	*create flag for waves skipped;
		cself_lproxy_skipf2_&y = &sk;
	end;
run;
title "checks for wave &y, lookback to 1994";
	proc freq; tables cself_lproxy_skipf2_&y;
run;
%mend;
%ch(00, 2, 94) %ch(98, 1, 94)
%ch(02, 2, 96) %ch(00, 1, 96) 
%ch(04, 2, 98) %ch(02, 1, 98) 
%ch(06, 2, 00) %ch(04, 1, 00) 
%ch(08, 2, 02) %ch(06, 1, 02) 
%ch(10, 2, 04) %ch(08, 1, 04) 
%ch(12, 2, 06) %ch(10, 1, 06) 
%ch(14, 2, 08) %ch(12, 1, 08) 
%ch(14, 1, 10) 

/******************************************************************************************
*	Add labels
******************************************************************************************/
%macro lab(y);
	data base; set base;
			label cself_lself2_&y = "Current wave SELF, last participation wave SELF indicator (limit to 2 waves missed), wave &y";
			label cself_lproxy2_&y = "Current wave SELF, last participation wave PROXY indicator (limit to 2 waves missed), wave &y";
			label cproxy_lproxy2_&y = "Current wave PROXY, last participation wave PROXY indicator (limit to 2 waves missed), wave &y";
			label cproxy_lself2_&y = "Current wave PROXY, last participation wave SELF indicator (limit to 2 waves missed), wave &y";

			label iword_sdch2_&y = "imm_word standardized change, for self-self and self-proxy respondents (limit to 2 waves missed), wave &y";
			label iwordsq_sdch2_&y = "imm_word_squared standardized change, for self-self and self-proxy respondents (limit to 2 waves missed), wave &y";
			label dword_sdch2_&y = "delayed_word standardized change, for self-self and self-proxy respondents (limit to 2 waves missed), wave &y";
			label tics13_sdch2_&y = "TICS_score(0-13) standardized change, for self-self and self-proxy respondents (limit to 2 waves missed), wave &y"; 
			label tics13sq_sdch2_&y = "TICS_squared(0-169) standardized change, for self-self and self-proxy respondents (limit to 2 waves missed), wave &y"; 
			label name_wrong_sdch2_&y = "object/pres/vp recall standardized change, for self-self and self-proxy respondents (any # waves missed), wave &y";
			label date_wrong_sdch2_&y = "date recall standardized change, for self-self and self-proxy respondents (limit to 2 waves missed), wave &y"; 
			label ser7_sdch2_&y = "serial7 standardized change, for self-self and self-proxy respondents (limit to 2 waves missed), wave &y"; 
			label bwc_sdch2_&y = "backwards_count standardized change, for self-self and self-proxy respondents (limit to 2 waves missed), wave &y";

			label IQCODE5_i_sdch2_&y = "IQCODE (with LOCF imputation) standardized change , for proxy-proxy respondents (limit to 2 waves missed), wave &y"; 
			label pr_memsc5_i_sdch2_&y = "proxy_memory_score (with LOCF imputation) standardized change, for proxy-proxy respondents (limit to 2 waves missed), wave &y";
			label jormsymp5_i_sdch2_&y = "5jorm_symptoms (with LOCF imputation) standardized change  change, for proxy-proxy respondents (limit to 2 waves missed), wave &y";

		*set laggedself (for proxies) to 0;
			label iword_lag2_&y = "imm_word lagged, for proxy_self respondents (limit to 2 waves missed), wave &y";
			label iwordsq_lag2_&y = "imm_word_squared lagged, for proxy_self respondents (limit to 2 waves missed), wave &y";
			label dword_lag2_&y = "delayed_word lagged, for proxy_self respondents (limit to 2 waves missed), wave &y";
			label tics13_lag2_&y = "TICS_score(0-13) lagged, for proxy_self respondents (limit to 2 waves missed), wave &y"; 
			label tics13sq_lag2_&y = "TICS_squared(0-169) lagged, for proxy_self respondents (limit to 2 waves missed), wave &y"; 
			label name_wrong_lag2_&y = "object/pres/vp recall lagged, for proxy_self respondents (limit to 2 waves missed), wave &y"; 
			label date_wrong_lag2_&y = "date recall lagged, for proxy_self respondents (limit to 2 waves missed), wave &y";
			label ser7_lag2_&y = "serial7 lagged, for proxy_self respondents (limit to 2 waves missed), wave &y";
			label bwc_lag2_&y = "backward_count lagged, for proxy_self respondents (limit to 2 waves missed), wave &y";

		*cself_lproxy flags;
			label cself_lproxy_skipf2_&y =  "# waves skipped to last self before proxy, for self_proxy respondents (limit 2 waves missed between self and proxy waves), wave &y";
	run;

%mend;
%lab(98) %lab(00) %lab(02) %lab(04) %lab(06) %lab(08) %lab(10) %lab(12) %lab(14)


/******************************************************************************************************************************
* Set proxy cogn to 0 for self-respondents
* Set self cogn to 0 for proxy-respondents
******************************************************************************************************************************/
%macro cogn(y);
	data base; set base;
		if proxy_&y = 0 then do;
			IQCODE5_i_&y = 0;
			pr_memsc5_i_&y = 0;
			jormsymp5_i_&y = 0;
		end;

		else if proxy_&y = 1 then do;
			iword_&y = 0;
			iwordsq_&y = 0;
			dword_&y = 0;
			tics13_&y = 0;
			tics13sq_&y = 0;
			name_wrong_&y = 0;
			date_wrong_&y = 0;
			ser7_&y = 0;
			bwc_&y = 0;
		end;
	run;

	proc means data=base nolabels; 
		var tics13_&y tics13sq_&y iword_&y iwordsq_&y dword_&y ser7_&y bwc_&y name_wrong_&y date_wrong_&y 
			IQCODE5_i_&y pr_memsc5_i_&y jormsymp5_i_&y;
		where proxy_&y = 0;
	run;
	proc means data=base nolabels;
		var tics13_&y tics13sq_&y iword_&y iwordsq_&y dword_&y ser7_&y bwc_&y name_wrong_&y date_wrong_&y 
			IQCODE5_i_&y pr_memsc5_i_&y jormsymp5_i_&y;
		where proxy_&y = 1;
	run;
%mend;
%cogn(98) %cogn(00) %cogn(02) %cogn(04) %cogn(06) 
%cogn(08) %cogn(10) %cogn(12) %cogn(14) 
/*******************************************************************
*	Create interaction terms
*		- (from Wu) dword_m, IQCODE_i_m
*		- (new) 
*			- lths*black lths*hisp
*			- ser7*black, ser7*Hisapnic, ser7*lths ser7*health1, ser7*health2
*			- iword*health1, iword*health2, dword*health1, dword*health2
*			- name*adl, date*adl, 
*			- name*nh_black, name*hispanic
*			- age*iadl
*			- proxy*age, proxy*lths, proxy*health1, proxy*health2, proxy*male, proxy*adl, proxy*iadl
*******************************************************************/
data base; set base;
	lths_black = lths*nh_black;
	lths_hisp =lths*hispanic;
run;

%macro int(y);
	data base; set base;

		dword_m_&y = dword_&y*male;
		IQCODE5_i_m_&y = IQCODE5_i_&y*male;

		age_iadl_&y = hrs_age70_&y*iadl_d_&y;

		ser7_black_&y = ser7_&y*NH_black;
		ser7_hisp_&y = ser7_&y*hispanic;
		ser7_lths_&y = ser7_&y*lths;
		ser7_health1_&y = ser7_&y*health_d1_&y;
		ser7_health2_&y = ser7_&y*health_d2_&y;
		iword_health1_&y = iword_&y*health_d1_&y;
		iword_health2_&y = iword_&y*health_d2_&y;
		dword_health1_&y = dword_&y*health_d1_&y;
		dword_health2_&y = dword_&y*health_d2_&y;
		date_adl_&y = date_wrong_&y*adl_d_&y;
		name_adl_&y = name_wrong_&y*adl_d_&y;
		name_black_&y = name_wrong_&y*NH_black;
		name_hisp_&y = name_wrong_&y*hispanic;
	
		proxy_age_&y = hrs_age70_&y*proxy_&y;
		proxy_lths_&y = proxy_&y*lths;
		proxy_health1_&y = proxy_&y*health_d1_&y;
		proxy_health2_&y = proxy_&y*health_d2_&y;
		proxy_male_&y = proxy_&y*male;
		proxy_adl_&y = proxy_&y*adl_d_&y;
		proxy_iadl_&y = proxy_&y*iadl_d_&y;
		
		proxy_bath_&y = proxy_&y*bath_&y;
	run;
%mend;
%int(98)%int(00)%int(02)%int(04)%int(06)%int(08)%int(10)%int(12)%int(14)


/******************************************************************************************
*	Create Final analytical dataset
******************************************************************************************/
proc sort data=base; by hhid pn; run;

data final; 
	set base (keep = hhid pn hacohort male female NH_white NH_black Hispanic NH_other LTHS HSGED GTHS lths_black lths_hisp); 
run;

%macro wave(y);
	data wave_&y; 
		set base (keep = hhid pn inw_&y iwmo_&y iwyr_&y randchf_&y hrs_wgt_&y
						 hrs_age70_&y hrs_age70sq_&y proxy_&y cself_lproxy2_&y 
						/*Hurd*/ hagecat75_&y hagecat80_&y hagecat85_&y hagecat90_&y proxy_lag_&y

						 /*self-cognition*/
						 tics13_&y tics13sq_&y iword_&y iwordsq_&y dword_&y ser7_&y bwc_&y name_wrong_&y date_wrong_&y 
						 tics13_sdch2_&y tics13sq_sdch2_&y iword_sdch2_&y iwordsq_sdch2_&y dword_sdch2_&y ser7_sdch2_&y bwc_sdch2_&y name_wrong_sdch2_&y date_wrong_sdch2_&y 
						 tics13_lag2_&y tics13sq_lag2_&y iword_lag2_&y iwordsq_lag2_&y dword_lag2_&y ser7_lag2_&y bwc_lag2_&y name_wrong_lag2_&y date_wrong_lag2_&y 
						 /*Only used for Hurd - separate self/proxy models - change variables missing for proxies*/date_recall_&y bwc1_&y scis_&y cact_&y pres_&y date_recallch_&y bwc1ch_&y ser7ch_&y scisch_&y cactch_&y presch_&y iwordch_&y dwordch_&y
						 /*Only used for Hurd - separate self/proxy models - lag variables missing for self*/date_recall_lag_&y ser7_lag_&y pres_lag_&y iword_lag_&y dword_lag_&y 
						 
						 /*proxy cognition*/
						 IQCODE5_i_&y pr_memsc5_i_&y jormsymp5_i_&y 
						 IQCODE5_i_sdch2_&y pr_memsc5_i_sdch2_&y
						 /*Only used for Hurd - separate self/proxy models - change var missing for self*/ IQCODE_i_&y IQCODEch_i_&y

						 /*physical functioning, health status*/
						 adl_&y adl_d_&y iadl_&y iadl_d_&y 
						 adl_sdch2_&y iadl_sdch2_&y
						 eat_&y bath_&y dress_&y phone_&y
						 /*Hurd*/ adlch_&y iadlch_&y

						 /*heatlh status and medical history*/
						 health_d1_&y health_d2_&y
						 healthst_sdch2_&y
						 hibp_&y diab_&y bmi25c_&y bmicat_&y

						 /*drinking*/
						 drinklvl_&y 

						 /*social engagement*/
						 volunteerhrs_&y helpothersyn_&y socialeng7_&y socialeng_d_&y
						 retyrcat_&y

						 /*interaction terms*/
						 dword_m_&y IQCODE5_i_m_&y
						 age_iadl_&y
						 ser7_black_&y ser7_hisp_&y ser7_lths_&y ser7_health1_&y ser7_health2_&y
						 iword_health1_&y iword_health2_&y dword_health1_&y dword_health2_&y
						 date_adl_&y name_adl_&y name_black_&y name_hisp_&y 
						 proxy_age_&y proxy_lths_&y proxy_health1_&y proxy_health2_&y proxy_male_&y proxy_adl_&y proxy_iadl_&y
						 proxy_bath_&y);
		run;

		proc means data=wave_&y nolabels;
			where proxy_&y = 1 and randchf_&y in (0, 1, 2);
		run;
		proc means data=wave_&y nolabels;
			where proxy_&y = 0 and randchf_&y in (0, 1, 2);
		run;

		data final;
			merge final wave_&y;
			by hhid pn;
		run;
%mend;
%wave(98)%wave(00)%wave(02)%wave(04)%wave(06)
%wave(08)%wave(10)%wave(12)%wave(14)

proc means data = final nolabels n mean min max; run;

/*SAVE*/
data x.newalg_allvars_98_14_&dt; set final; run;

