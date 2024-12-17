/**********************************************************************************************************************
*
*	Created 2019_0211, updated 2019_1202 and 2021_1109 and 2022_0519 and 2024_1217
*		- Original code used to assign algorithmic diagnoses for Medicare paper (code uploaded to Github under AD_Algorithm_Development)
*		- Apply new algorithms to each wave and get compile dataset with predicted probabilities and classifications
*
*		- 2019_1202: Added raehsamp, raestrat, diab_&y and hipb_&y to dataset
*		- 2021_1109: Updated to go through 2016 using RAND_2018_v1 HRS data;
*		- 2022_0519:  Updated to go thorugh 2018 with interim data
*		- 2024_1217:  Updated to go through 2020 with RAND_2020_V2 HRS data;
*		
**********************************************************************************************************************/

%include "F:\power\HRS\Dementia algorithms code 2024_1206\Update_from_lastversion\1. Extract variables for recommended models all HRS_20241217.sas";

data pred; 
	set final;

	if NH_white = 1 then raceeth = "1. NH_white";
	else if NH_black = 1 then raceeth = "2. NH_black";
	else if Hispanic = 1 then raceeth = "3. Hispanic";

	else delete;

	proc sort; by raceeth;

run;


/*****************************
*
*	EXPERT MODEL
*
*****************************/

proc import datafile = "F:\power\HRS\Dementia algorithms code 2024_1206\Update_from_lastversion\Model Coefficients_2019_0311.xlsx"
dbms = xlsx
out = expert
replace;
sheet = "Expert";
run;

proc transpose data=expert out = expert_coef; run;
data expert_coef; set expert_coef (drop = _name_ _label_); run;

proc sql;
	create table fit_expert as
	select * 
	from pred, expert_coef;
quit;


%macro fit (y);

title "Expert: year &y";
	data fit_expert; set fit_expert;

		expert_or_&y = exp(col1 + col2*hrs_age70_&y + col3*hrs_age70sq_&y  + col4*male + col5*NH_black + col6*hispanic + col7*LTHS + col8*LTHS_black + col9*LTHS_hisp
								 	+ col10*health_d2_&y + col11*adl_d_&y + col12*iadl_d_&y + col13*age_iadl_&y + col14*diab_&y + col15*socialeng_d_&y + col16*proxy_&y
									+ col17*ser7_&y + col18*ser7_black_&y + col19*ser7_hisp_&y + col20*ser7_lths_&y + col21*ser7_health2_&y 
									+ col22*iword_&y + col23*dword_&y + col24*iword_health2_&y + col25*dword_health2_&y
									+ col26*date_wrong_&y + col27*date_adl_&y + col28*name_wrong_&y + col29*name_black_&y + col30*name_hisp_&y + col31*name_adl_&y
									+ col32*IQCODE5_i_&y + col33*pr_memsc5_i_&y + col34*jormsymp5_i_&y
									+ col35*proxy_age_&y + col36*proxy_lths_&y + col37*proxy_health2_&y + col38*proxy_male_&y + col39*proxy_adl_&y + col40*proxy_iadl_&y);
		expert_p_&y = expert_or_&y/(1+expert_or_&y);

		if NH_white = 1 then do;
			if expert_p_&y > 0.27 then expert_dem_&y = 1;
			else if expert_p_&y NE . then expert_dem_&y = 0;
		end;

		else if NH_black = 1 then do;
			if expert_p_&y > 0.32 then expert_dem_&y = 1;
			else if expert_p_&y NE . then expert_dem_&y = 0;
		end;

		else if Hispanic = 1 then do;
			if expert_p_&y > 0.46 then expert_dem_&y = 1;
			else if expert_p_&y NE . then expert_dem_&y = 0;
		end;

		label expert_p_&y = "Expert model predicted dementia probability, year &y";
		label expert_dem_&y = "Expert model dementia classification using race/ethnicity-specific cutoffs, year &y";

		proc freq; 
			tables expert_dem_&y; 
			by raceeth;
			where hrs_age70_&y ge 0;
			weight hrs_wgt_&y;
	run;


%mend;
%fit(98) %fit(00) %fit(02) %fit(04)
%fit(06) %fit(08) %fit(10) %fit(12)
%fit(14) %fit(16) %fit(18) %fit(20)

/*****************************
*
*	LASSO MODEL
*
*****************************/

proc import datafile = "F:\power\HRS\Dementia algorithms code 2024_1206\Update_from_lastversion\Model Coefficients_2019_0311.xlsx"
dbms = xlsx
out = lasso
replace;
sheet = "LASSO";
run;

proc transpose data=lasso out = lasso_coef; run;
data lasso_coef; set lasso_coef (drop = _name_ _label_); run;

proc sql;
	create table fit_lasso as
	select * 
	from pred, lasso_coef;
quit;

%macro fit (y);

title "LASSO: year &y";
	data fit_lasso; set fit_lasso;

		lasso_or_&y = exp(col1 + col2*male + col3*hispanic + col4*lths + col5*lths_black + col6*hrs_age70_&y 
								+ col7*iword_&y + col8*dword_&y + col9*iwordsq_&y + col10*ser7_&y + col11*bwc_&y + col12*tics13_&y + col13*tics13sq_&y
								+ col14*iadl_&y + col15*adl_d_&y + col16*eat_&y + col17*bath_&y + col18*dress_&y + col19*phone_&y
								+ col20*health_d1_&y + col21*healthst_sdch2_&y + col22*adl_sdch2_&y + col23*hibp_&y + col24*bmi25c_&y + col25*bmicat_&y
								+ col26*drinklvl_&y + col27*retyrcat_&y + col28*volunteerhrs_&y + col29*helpothersyn_&y + col30*socialeng7_&y + col31*iadl_sdch2_&y
								+ col32*IQCODE5_i_&y + col33*pr_memsc5_i_&y + col34*jormsymp5_i_&y + col35*cself_lproxy2_&y 
								+ col36*dword_sdch2_&y + col37*tics13_sdch2_&y + col38*date_wrong_sdch2_&y + col39*name_wrong_sdch2_&y + col40*bwc_sdch2_&y
								+ col41*IQCODE5_i_sdch2_&y + col42*pr_memsc5_i_sdch2_&y + col43*iwordsq_lag2_&y + col44*dword_lag2_&y + col45*tics13sq_lag2_&y + col46*date_wrong_lag2_&y
								+ col47*dword_m_&y + col48*IQCODE5_i_m_&y + col49*ser7_health1_&y + col50*ser7_health2_&y + col51*dword_health1_&y 
								+ col52*date_adl_&y + col53*name_adl_&Y + col54*name_black_&y + col55*proxy_health1_&y + col56*proxy_male_&y + col57*proxy_bath_&y);
		lasso_p_&y = lasso_or_&y/(1+lasso_or_&y);

		if NH_white = 1 then do;
			if lasso_p_&y > 0.25 then lasso_dem_&y = 1;
			else if lasso_p_&y NE . then lasso_dem_&y = 0;
		end;

		else if NH_black = 1 then do;
			if lasso_p_&y > 0.19 then lasso_dem_&y = 1;
			else if lasso_p_&y NE . then lasso_dem_&y = 0;
		end;

		else if Hispanic = 1 then do;
			if lasso_p_&y > 0.34 then lasso_dem_&y = 1;
			else if lasso_p_&y NE . then lasso_dem_&y = 0;
		end;

		label lasso_p_&y = "LASSO model predicted dementia probability, year &y";
		label lasso_dem_&y = "LASSO model dementia classification using race/ethnicity-specific cutoffs, year &y";

		proc freq; 
			tables lasso_dem_&y; 
			by raceeth;
			where hrs_age70_&y ge 0;
			weight hrs_wgt_&y;
	run;


%mend;
%fit(98) %fit(00) %fit(02) %fit(04)
%fit(06) %fit(08) %fit(10) %fit(12)
%fit(14) %fit(16) %fit(18) %fit(20)

/*****************************
*
*	HURD
*
*****************************/

proc import datafile = "F:\power\HRS\Dementia algorithms code 2024_1206\Update_from_lastversion\Model Coefficients_2019_0311.xlsx"
dbms = xlsx
out = hurd_s
replace;
sheet = "Hurd_s";
run;
proc transpose data=hurd_s out = hurd_s_coef; run;
data hurd_s_coef; set hurd_s_coef (drop = _name_ _label_); run;

proc import datafile = "F:\power\HRS\Dementia algorithms code 2024_1206\Update_from_lastversion\Model Coefficients_2019_0311.xlsx"
dbms = xlsx
out = hurd_p
replace;
sheet = "Hurd_p";
run;
proc transpose data=hurd_p out = hurd_p_coef; run;
data hurd_p_coef; set hurd_p_coef (drop = _name_ _label_); run;

proc sql;
	create table fit_hurd_s as
	select * 
	from pred, hurd_s_coef;
quit;

%macro fit(y);

	data fit_hurd_s; set fit_hurd_s;

		if proxy_&y = 0 then hurd_p_s_&y = probnorm(col28 - (col1*hagecat75_&y + col2*hagecat80_&y + col3*hagecat85_&y + col4*hagecat90_&y
									+ col5*HSGED + col6*GTHS + col7*female + col8*adl_&y + col9*iadl_&y + col10*adlch_&y + col11*iadlch_&y
									+ col12*date_recall_&y + col13*bwc1_&y + col14*ser7_&y + col15*scis_&y + col16*cact_&y + col17*pres_&y + col18*iword_&y + col19*dword_&y
									+ col20*date_recallch_&y + col21*bwc1ch_&y + col22*ser7ch_&y + col23*scisch_&y + col24*cactch_&y + col25*presch_&y + col26*iwordch_&y + col27*dwordch_&y));

	proc means;
		var hurd_p_s_&y;
	run;

%mend;
%fit(98) %fit(00) %fit(02) %fit(04)
%fit(06) %fit(08) %fit(10) %fit(12)
%fit(14) %fit(16) %fit(18) %fit(20)
	

proc sql;
	create table fit_hurd_p as
	select * 
	from pred, hurd_p_coef;
quit;	

%macro fit(y);

	data fit_hurd_p; set fit_hurd_p;

		if proxy_&y = 1 then hurd_p_p_&y = probnorm(col20 - (col1*hagecat75_&y + col2*hagecat80_&y + col3*hagecat85_&y + col4*hagecat90_&y
										+ col5*HSGED + col6*GTHS + col7*female + col8*adl_&y + col9*iadl_&y + col10*adlch_&y + col11*iadlch_&y
										+ col12*iqcode_i_&y + col13*proxy_lag_&y + col14*iqcodech_i_&y 
										+ col15*date_recall_lag_&y + col16*ser7_lag_&y + col17*pres_lag_&y + col18*iword_lag_&y + col19*dword_lag_&y));
	proc means;
		var hurd_p_p_&y;
	run;

%mend;
%fit(98) %fit(00) %fit(02) %fit(04)
%fit(06) %fit(08) %fit(10) %fit(12)
%fit(14) %fit(16) %fit(18) %fit(20)

proc sort data=fit_hurd_s; by hhid pn; run;
proc sort data=fit_hurd_p; by hhid pn; run;
		
data hurd_pred;
	merge fit_hurd_s (keep = hhid pn raehsamp raestrat NH_white NH_black hispanic raceeth Male LTHS HSGED GTHS  
							 hrs_age70_98 hrs_age70_00 hrs_age70_02 hrs_age70_04 hrs_age70_06 hrs_age70_08 hrs_age70_10 hrs_age70_12 hrs_age70_14 hrs_age70_16  hrs_age70_18 hrs_age70_20
							 proxy_98 proxy_00 proxy_02 proxy_04 proxy_06 proxy_08 proxy_10 proxy_12 proxy_14  proxy_16 proxy_18 proxy_20
							 hrs_wgt_98 hrs_wgt_00 hrs_wgt_02 hrs_wgt_04 hrs_wgt_06 hrs_wgt_08 hrs_wgt_10 hrs_wgt_12 hrs_wgt_14   hrs_wgt_16 hrs_wgt_18 hrs_wgt_20
							 hurd_p_s_98 hurd_p_s_00 hurd_p_s_02 hurd_p_s_04 hurd_p_s_06 hurd_p_s_08 hurd_p_s_10 hurd_p_s_12 hurd_p_s_14 hurd_p_s_16 hurd_p_s_18 hurd_p_s_20 )
		 fit_hurd_p (keep = hhid pn hurd_p_p_98 hurd_p_p_00 hurd_p_p_02 hurd_p_p_04 hurd_p_p_06 hurd_p_p_08 hurd_p_p_10 hurd_p_p_12 hurd_p_p_14 hurd_p_p_16 hurd_p_p_18 hurd_p_p_20 );
	by hhid pn;

	proc sort; by raceeth;
run;
			
%macro fit(y);

title "Hurd: year &y";
data hurd_pred; set hurd_pred;

	if proxy_&y = 0 then hurd_p_&y = hurd_p_s_&y;
	else if proxy_&y = 1 then hurd_p_&y = hurd_p_p_&y;

	if NH_white = 1 then do;
		if hurd_p_&y > 0.19 then hurd_dem_&y = 1;
		else if hurd_p_&y NE . then hurd_dem_&y = 0;
	end;

	else if NH_black = 1 then do;
		if hurd_p_&y > 0.25 then hurd_dem_&y = 1;
		else if hurd_p_&y NE . then hurd_dem_&y = 0;
	end;

	else if Hispanic = 1 then do;
		if hurd_p_&y > 0.27 then hurd_dem_&y = 1;
		else if hurd_p_&y NE . then hurd_dem_&y = 0;
	end;

	label hurd_p_&y = "Hurd model predicted dementia probability, year &y";
	label hurd_dem_&y = "Hurd model dementia classification using race/ethnicity-specific cutoffs, year &y";

	proc freq; 
		tables hurd_dem_&y; 
		by raceeth;
		where hrs_age70_&y ge 0;
		weight hrs_wgt_&y;
run;

%mend;
%fit(98) %fit(00) %fit(02) %fit(04)
%fit(06) %fit(08) %fit(10) %fit(12)
%fit(14) %fit(16) %fit(18) %fit(20)



/*create final dataset*/
proc sort data=hurd_pred;
	by hhid pn;
run;
proc sort data=fit_expert;
	by hhid pn;
run;
proc sort data=fit_lasso;
	by hhid pn;
run;

data final;
	merge hurd_pred (drop = hurd_p_s_98 hurd_p_s_00 hurd_p_s_02 hurd_p_s_04 hurd_p_s_06 hurd_p_s_08 hurd_p_s_10 hurd_p_s_12 hurd_p_s_14 hurd_p_s_16 hurd_p_s_18 hurd_p_s_20  
							hurd_p_p_98 hurd_p_p_00 hurd_p_p_02 hurd_p_p_04 hurd_p_p_06 hurd_p_p_08 hurd_p_p_10 hurd_p_p_12 hurd_p_p_14 hurd_p_p_16 hurd_p_p_18 hurd_p_p_20 )
		  fit_expert (keep = hhid pn expert_p_98 expert_p_00 expert_p_02 expert_p_04 expert_p_06 expert_p_08 expert_p_10 expert_p_12 expert_p_14 expert_p_16  expert_p_18 expert_p_20
		  							 expert_dem_98 expert_dem_00 expert_dem_02 expert_dem_04 expert_dem_06 expert_dem_08 expert_dem_10 expert_dem_12 expert_dem_14 expert_dem_16  expert_dem_18 expert_dem_20)
		  fit_lasso (keep = hhid pn lasso_p_98 lasso_p_00 lasso_p_02 lasso_p_04 lasso_p_06 lasso_p_08 lasso_p_10 lasso_p_12 lasso_p_14  lasso_p_16 lasso_p_18 lasso_p_20
		  							 lasso_dem_98 lasso_dem_00 lasso_dem_02 lasso_dem_04 lasso_dem_06 lasso_dem_08 lasso_dem_10 lasso_dem_12 lasso_dem_14 lasso_dem_16  lasso_dem_18 lasso_dem_20
									hibp_98 hibp_00 hibp_02 hibp_04 hibp_06 hibp_08 hibp_10 hibp_12 hibp_14 hibp_16 hibp_18  hibp_20
									diab_98 diab_00 diab_02 diab_04 diab_06 diab_08 diab_10 diab_12 diab_14 diab_16 diab_18 diab_20  );
    by hhid pn;
	proc contents;
run;

data final_wide; set final;
run;


/******************************************
*	convert to long
******************************************/


%macro long(y, yr);
data w&y; set final;
	rename proxy_&y = proxy;
	rename hrs_age70_&y = hrs_age70;
	rename diab_&y = diab;
	rename hibp_&y = hibp;
	rename hrs_wgt_&y = hrs_wgt;

	rename expert_p_&y = expert_p;
	rename expert_dem_&y = expert_dem;
	rename lasso_p_&y = lasso_p;
	rename lasso_dem_&y = lasso_dem;
	rename hurd_p_&y = hurd_p;
	rename hurd_dem_&y = hurd_dem;

	HRS_year = "&yr";

	keep hhid pn raehsamp raestrat HRS_year proxy_&y hrs_age70_&y diab_&y hibp_&y hrs_wgt_&y expert_p_&y expert_dem_&y lasso_p_&y lasso_dem_&y hurd_p_&y hurd_dem_&y;
run;
%mend;
%long(98, 1998) %long(00, 2000) %long(02, 2002) %long(04, 2004) %long(06, 2006) %long(08, 2008)
%long(10, 2010) %long(12, 2012) %long(14, 2014) %long(16, 2016) %long(18, 2018) %long(20, 2020)

data final_long;
	set w98 w00 w02 w04 w06 w08 w10 w12 w14 w16 w18 w20;

	label hibp = "doctor told you that you had hypertension";
	label diab = "doctor told you that you had diabetes";
	label proxy = "proxy respondent";
	label hrs_age70 = "Age at interview centered at 70";
	label hrs_wgt = "HRS sampling weight (community- and NH-dwellers)";
	label expert_p = "Expert model predicted dementia probability";
	label expert_dem = "Expert model dementia classification using race/ethnicity-specific cutoffs";
	label LASSO_p = "LASSO model predicted dementia probability";
	label LASSO_dem = "LASSO model dementia classification using race/ethnicity-specific cutoffs";
	label Hurd_p = "Hurd model predicted dementia probability";
	label Hurd_dem = "Hurd model dementia classification using race/ethnicity-specific cutoffs";
	proc sort;
		by hhid pn HRS_year;
run;

data final_long;
	merge final (keep = hhid pn raehsamp raestrat male NH_White NH_black Hispanic raceeth LTHS HSGED GTHS)
	      final_long;
	by hhid pn;
run;


libname out 'F:\power\HRS\Dementia algorithms code 2024_1206\Update_from_lastversion\';
/*data out.final_wide_2000_2020; set final_wide; run;
data out.final_long_2000_2020; set final_long; run;*/

*delete interim datasets;
proc datasets library=work nolist;
save final_wide final_long;
quit;
run;

*subset dataset for distribution by HRS as user-submitted dataset;
data hrsdementia_2024_1217; set final_long;
if hrs_age70<0 then delete; *only for those age 70+ at each interview;
if hrs_year <2000 then delete;
keep hhid pn hrs_year expert_p expert_dem LASSO_p LASSO_dem hurd_p hurd_dem;
run;
data out.hrsdementia_2024_1217; set hrsdementia_2024_1217; run;


ods pdf file = "Stats dementia classification v2024 using RAND 2020 V2 - 20241217.pdf";
TITLE "2024_1217 Distribution - Using RAND 2020 V2";
*compare current and prior distribution of stats;
proc sort data=hrsdementia_2024_1217; by hrs_year; run;
proc means data= hrsdementia_2024_1217; by hrs_year; run;

ods pdf close;
/**/
/*ods pdf file = "Stats dementia classification v2022 (incl 2018 interim) using RAND 2020 V2 - 20241217.pdf";*/
/*TITLE "2022_0519 Distribution - Using RAND 2020 V2";*/
/**compare current and prior distribution of stats;*/
/*proc sort data=hrsdementia_2022_0519_newRAND; by hrs_year; run;*/
/*proc means data= hrsdementia_2022_0519_newRAND; by hrs_year; run;*/
/**/
/*ods pdf close;*/

/*ods pdf file = "Stats dementia classification v2019.pdf";*/
/*TITLE "2019_1028 Distribuion - Using RAND 2014 V2";*/
/**read in dataset originally distributed to HRS;*/
/*data hrsdementia_2019_1028; set out.hrsdementia_2019_1028; run;*/
/*proc sort data=hrsdementia_2019_1028; by hrs_year; run;*/
/*proc means data= hrsdementia_2019_1028; by hrs_year; run;*/
/*ods pdf close;*/

/**/
/*ods pdf file = "Stats dementia classification v2021 (currently on website to 2016) using RAND 2018 V1 - 20241217.pdf";*/
/*TITLE "2021_1109 Distribution - Using RAND 2018 V1";*/
/**compare current and prior distribution of stats;*/
/*data hrsdementia_2021_1109; set out.hrsdementia_2021_1109; run;*/
/*proc sort data=hrsdementia_2021_1109; by hrs_year; run;*/
/*proc means data= hrsdementia_2021_1109; by hrs_year; run;*/
/**/
/*ods pdf close;*/
/**/





