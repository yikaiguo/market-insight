/* create a libname */
libname  cl '/folders/myfolders/clientloyalty';

/* import data */
proc import datafile = '/folders/myfolders/clientloyalty/client.xlsx'
dbms = xlsx
out = cl.client_loyalty
replace;
sheet = 'CaseData';
getnames =yes;
run;

/* change column name */
/*variable name:NOTE:    Variable Name Change.  Customer Age (in months) -> Customer_Age__in_months_        
 NOTE:    Variable Name Change.  Churn (1 = Yes, 0 = No) -> VAR3                            
 NOTE:    Variable Name Change.  CHI Score Month 0 -> CHI_Score_Month_0               
 NOTE:    Variable Name Change.  CHI Score 0-1 -> CHI_Score_0_1                   
 NOTE:    Variable Name Change.  Support Cases Month 0 -> Support_Cases_Month_0           
 NOTE:    Variable Name Change.  Support Cases 0-1 -> Support_Cases_0_1               
 NOTE:    Variable Name Change.  SP Month 0 -> SP_Month_0                      
 NOTE:    Variable Name Change.  SP 0-1 -> SP_0_1                          
 NOTE:    Variable Name Change.  Logins 0-1 -> Logins_0_1                      
 NOTE:    Variable Name Change.  Blog Articles 0-1 -> Blog_Articles_0_1               
 NOTE:    Variable Name Change.  Views 0-1 -> Views_0_1                       
 NOTE:    Variable Name Change.  Days Since Last Login 0-1 -> _Days_Since_Last_Login_0_1 */

/* create a duplicate table called cl.renamed with simpler column names */
proc sql;
create table cl.renamed as
select id as id, Customer_Age__in_months_ as age, var3 as churn, chi_score_month_0 as chi0, support_cases_month_0 as support0, support_cases_0_1 as support01, sp_month_0 as sp0,sp_0_1 as sp01, logins_0_1 as login, blog_articles_0_1 as blog, views_0_1 as views, _days_since_last_login_0_1 as lastlogin from cl.client_loyalty;
quit;

/* get basic information */
proc contents data = cl.renamed;
run;

/* get means of all data */
proc means data = cl.renamed;
run;

/* get frequency of all data 
proc freq data = cl.renamed;
run;*/
/* examined the resulted and noticed that the data of 'view' is abnormal */

/*since a lot of value is missing, create new columns denoting the missing status*/
data cl.renamed_missing_ind;
set cl.renamed;
if (churn ne 0)*(chi0 ne 0)*(support0 ne 0)*(support01 ne 0)*(sp0 ne 0)*(sp01 ne 0)*(login ne 0)*(blog ne 0)*(views ne 0)*(lastlogin ne 0)=0 then missing =1;
else missing = 0;
if (churn ne 0)+(chi0 ne 0)+(support0 ne 0)+(support01 ne 0)+(sp0 ne 0)+(sp01 ne 0)+(login ne 0)+(blog ne 0)+(views ne 0)+(lastlogin ne 0)=0 then all_missing =1;
else all_missing = 0;
run;
/* count missing */
proc sql;
select count(missing) as missing_count from (select missing from cl.renamed_missing_ind
where missing = 1);
quit;
/* count all_missing */
proc sql;
select count(all_missing) as all_missing_count from (select all_missing from cl.renamed_missing_ind
where all_missing = 1);
quit;

/* dataset v1: eliminate all_missing rows, primary dataset for further analysis */
proc sql;
create table cl.renamed_v1 as
select * from cl.renamed_missing_ind where all_missing = 0;
quit;

/* dataset v2: eliminate missing rows */
proc sql; 
create table cl.renamed_v2 as 
select * from cl.renamed_missing_ind where missing =0;
quit;
/* CONCLUSTION 1: only 6 rows have integrate data, therefore, further analysis must deal with missing data */

/* dataset v3: eliminate missing rows */
proc sql; 
create table cl.renamed_v3 as 
select * from cl.renamed_missing_ind where all_missing =1;
quit;

/*as the case description meantioned that when the customer age is low, e.g. 1 or 2
there is a high probability that no data is provided for that user. Draw a piechart
of v3 to find out the related customer age*/

/* Define Pie template */
proc template;
	define statgraph SASStudio.Pie;
		begingraph;
		entrytitle "Customer Age Distribution of All Missing Data" / 
			textattrs=(size=14);
		layout region;
		piechart category=age / stat = pct datalabellocation=outside 
			fillattrs=(transparency=0.10) dataskin=pressed;
		endlayout;
		endgraph;
	end;
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgrender template=SASStudio.Pie data=CL.RENAMED_V3;
run;

ods graphics / reset;

/*Question 1: Mr. Well (the case protagonist) believes that two important predictors of customer churn
are Customer Age (i.e., tenure with QWE) and CHI score. Does your data analysis
support these beliefs? */

/* do a logistics regression analysis on the v1 dataset, and investigate realted 
variables, choose logistics regression because the dependent variable is binomial
e.g 0 or 1*/
/*Model: ln(P(churn)/(1-P(churn))) = B0 + B1*age + B2*chi0 + B3*sp0 + B4*sp01 + B5*supoort01 + B6*login
+ B7*blog + B8*views + B9*lastlogin*/
/* Overall F-Test */
/* H0: B1 = B2 = B3 = B4 = B5 = B6 = B7 = B8 = 0, H1: at least one B value does not 
equal to 0*/
proc logistic data = cl.renamed_v1 descending;/*descending models '1's instead of '0's*/
model churn = age chi0 sp0 sp01 support0 support01 login blog views lastlogin;
run;

/* by checking the p-value of individual Chi-Sq test, we know that chi0, views and
lastlogin is significant at 95% confidence level*/
/* new model: ln(P(churn-hat)/(1-P(churn-hat))) = B0 + B1-hat*chi0 + B2-hat*views + 
B3-hat*lastlogin */
/* NOTE: p of H0 is 0.0001, which suggests extremely strong evidence that the model is working*/


/* Do a Partial Chi-Sq test to see if other variables combined is related or not */
/* H0 = B1-hat = B2-hat = B3-hat = 0, H: at least one B value does not euqal to 0 */
proc logistic data = cl.renamed_v1 descending;
model churn = chi0 views lastlogin;
store logimodel1;
run;

proc plm source = logimodel1;
effectplot fit(x=chi0);
run;
/* Chi-sq value = 2333.251 - 2318.277 = 14.974 (difference in -2 Log L) with a degree of
freedom of 9-3 = 6, so by looking up in Google, we know that p is 0.02046 < 0.05, so 
reject null hypothesis. We can conclude that there are significant evidence 
that the 3 factors we used in the second model affects customer churn at 95% confidence level*/



/* QUESTION1 CONCLUSION: according to the logistic model, 3 factors are related: chi0,
views, and lastlogin for the age group of 3-47. */
/* FINAL MODEL: P(churn)/(1-P(churn))  = e^ (-1.96539 -0.0105*chi0 -0.00012*views
+ 0.00786*lastlogin */
/* Example: What is the propability for a customer to churn if his chi0 is 50, views = 
-50, and lastlogin = 31, then P/(1-P) = e^(-1.9653  -0.0105*50 -0.00012*-50 +0.00786*31) 
= 0.10639, therefore, P (churn) = 0.0961596 ~= 0.1 */

/*QUESTION2: Is there a natural customer segmentation with respect to churn risk that QWE should be
thinking about? If so, what is it? What churn factors are particularly important in different
segments? Or does the same set of factors impact all customers, and thus segmentation
is not particularly useful?*/

/* Create new dataset v4 that contains a new column called churn_risk */
proc sql;
create table cl.renamed_v4 as
select *,avg(churn) as churn_risk from cl.renamed_v1
group by age;
quit;

/* Make customer segements base on age for 2 reasons: 1.no missing data, 2.make sense*/
proc sql;
create table cl.renamed_v5 as
select age,avg(churn) as churn_risk from cl.renamed_v1
group by age;
quit;

/* remove outliers*/
data cl.renamed_v5;
set cl.renamed_v5;
by age;
if age=1 then delete;
else if age = 2 then delete;
else if churn_risk = 0 then delete;
run;

proc sgplot data=CL.RENAMED_V5;
	scatter x=age y=churn_risk /;
	xaxis grid;
	yaxis grid;
run;

/*no obvious distribution identified, try fitting distribution with qq-plots for age 3-47*/

proc univariate data=CL.RENAMED_V5;
	ods select QQPlot;
	var churn_risk;

	/* Fitting Distributions */
	qqplot churn_risk / beta(alpha=est beta=est sigma=1 theta=0);
	qqplot churn_risk / exp(sigma=est theta=0);
	qqplot churn_risk / gamma(alpha=est sigma=est theta=0);
	qqplot churn_risk / lognormal(sigma=est theta=0 zeta=est);
	qqplot churn_risk / weibull(c=est sigma=est theta=0);
run;
/* by obeservation both gemma and lognormal could work */

/* do a k-s test for further analysis*/
proc univariate data=CL.RENAMED_V5;
	ods select Histogram GoodnessOfFit;
	var churn_risk;

	/* Fitting Distributions */
	histogram churn_risk / gamma(alpha=est sigma=est theta=0);
	histogram churn_risk / lognormal(sigma=est theta=0 zeta=est);
run;
/*both p-value > test statistics, but we use lognormal because it has a larger p-value*/
/*Distribution of churn_risk for age 3-47, ~Lognormal(theta = 0, sigma = 0.63, zeta = -2.9)*/
/*Right Skewed*/


/*Update database by assigning age group to them, 1-2 = S(short), 3-47 = M(medium),
>47 = L (long)*/
data cl.age_group;
set cl.renamed;
if age<3 then age_group = 'S';
else if age<48 then age_group = 'M';
else age_group = 'L';
run;

/* run logistics model again, including the age group*/
proc logistic data=CL.AGE_GROUP;
	class age_group / param=glm;
	model churn(event='1.0')=age_group chi0 views lastlogin / link=logit 
		technique=fisher;
	store logimodel;
run;

proc plm source = logimodel;
effectplot slicefit(x=chi0 sliceby = age_group);
run;
/*QUESTION2 CONCLUSION: 3 customer segmetation by age: 1. 0-2, 2. 3-47, 3. 48-67.
However, the group 1 and 3 are rather insignificant in terms of predicting customer
churn as suggested by the p-value.*/

/*QUESTION3: A proactive customer retention program should be focused on a small subset of
particularly risky customers. Can you identify such a subset? How accurate is your churn
prediction mechanism for this subset? (Hint: think and discuss what “accuracy” means in
this context)*/

/*Knowing that the customer churn is only related to chi0, views, and lastlogin,
we can classify these variables into smaller subsets*/

/*delete uncessary data*/
data cl.risk;
set cl.renamed_v1;
keep id churn chi0 views lastlogin;
run;

proc freq data = cl.risk;
run;
/*NOTE: Assume that all 0s are missing value, assign rank:missing to them*/

/*get non-zero chi0*/
proc sql;
create table cl.rank1 as 
select id, chi0 from cl.risk
where chi0 ne 0
order by chi0;
quit;


/*get non-zero views*/
proc sql;
create table cl.rank2 as 
select id,views from cl.risk
where views ne 0
order by views;
quit;


/*get non-zero lastlogin*/
proc sql;
create table cl.rank3 as 
select id, lastlogin from cl.risk
where lastlogin ne 0
order by lastlogin;
quit;

/*Use k-means clustering to define different clusters for different variables*/


/*VARIABLE1: chi0*/
%let variable = chi0;

proc fastclus data=cl.rank1 maxclusters=6 maxiter=200 drift out = cl.cluster_&variable;
	var &variable;
run;

/* NOTE: choose 6 clusters because that R-Squared would just pass 0.95*/

proc sql;
create table cl.risk_v3 as 
select a.*, cluster as cluster_&variable  from cl.risk as a left join cl.cluster_&variable as b on a.id = b.id;
quit;


/*VARIABLE2: views*/
%let variable = views;


proc fastclus data=cl.rank2 maxclusters=5 maxiter=200 drift out = cl.cluster_&variable;
	var &variable;
run;

/* NOTE: choose 5 clusters because that R-Squared would then pass 0.95*/

/*join*/
proc sql; 
create table cl.risk_v4 as 
select a.*,cluster as cluster_&variable  from cl.risk_v3 as a left join cl.cluster_&variable as b on a.id = b.id;
quit;

/*VARIABLE3: lastlogin*/
%let variable = lastlogin;


proc fastclus data=cl.rank3 maxclusters= 10 maxiter=200 drift out = cl.cluster_&variable;
	var &variable;
run;

/* NOTE: choose 10 clusters because that R-Squared would then pass 0.95*/

proc sql;
create table cl.risk_v5 as
select a.*, cluster as cluster_&variable  from cl.risk_v4 as a left join cl.cluster_&variable as b on a.id = b.id;
quit;

data cl.risk_v5;
set cl.risk_v5;
chi0_char = put(cluster_chi0, best8.);
views_char = put(cluster_views, best8.);
lastlogin_char = put(cluster_lastlogin, best8.);
run;
/* run logistic model and use coefficient to define the risk group, e.g coefficient<-10*/
proc logistic data=CL.RISK_V5 plots=all;
	class chi0_char views_char lastlogin_char / param=glm;
	model churn(event='1.0')=chi0_char | views_char | lastlogin_char @3 / 
		link=logit technique=fisher;
run;
/*Copied Analysis of estimate to excel called results*/

/*import the tested results in excel*/
proc import datafile= '/folders/myfolders/results.xlsx'
dbms =xlsx
out=cl.results
replace;
getnames= yes;
run;

/*change format of p_value*/
data cl.results_v1;
set cl.results;
if p ='.' then delete;
p_value = input(p,best10.);
run;

/*select risk group where estimate >1 and p_value<0.05*/
proc sql;
create table cl.risk_group as 
select * from cl.results_v1
where estimate >1 and p_value < 0.05;
quit;

/*select risk group1 where lastlogin is missing*/
proc sql;
create table cl.risk_group1 as 
select * from cl.results_v1
where estimate >1 and p_value < 0.05 and lastlogin is missing and views is not missing;
quit;

/*select risk group2 where lastlogin is not missing*/
proc sql;
create table cl.risk_group2 as 
select * from cl.results_v1
where estimate >1 and p_value < 0.05 and lastlogin is not missing;
quit;

/*change format of group1*/
data cl.risk_group1;
set cl.risk_group1;
chi0_num = input(chi0,best8.);
views_num = input(views,best8.);
run;

/*drop the first obs in group 2 since all data is missing and change format*/
data cl.risk_group2;
set cl.risk_group2;
if chi0='.' and lastlogin = '.' then delete;
chi0_num = input(chi0,best8.);
views_num = input(views,best8.);
lastlogin_num = input(lastlogin,best8.);
run;

/*select all risk users for group1*/
proc sql;
create table cl.risk_users1 as
select distinct chi0_num,views_num,id,churn from cl.risk_group1 as a
inner join cl.risk_v5 as b
on a.chi0_num = b.cluster_chi0 and a.views_num = b.cluster_views
order by churn desc;
quit;

/*calculate churn risk*/
/* churn risk: 82/686*/

/*select all risk users for group2*/
proc sql;
create table cl.risk_users2 as
select distinct chi0_num,views_num,lastlogin_num,id,churn from cl.risk_group2 as a
inner join cl.risk_v5 as b
on a.chi0_num = b.cluster_chi0 and a.views_num = b.cluster_views and a.lastlogin_num=
b.cluster_lastlogin
order by churn desc;
quit;

/*calculate churn risk*/
/* churn risk: 44/383*/

/*Combined churn risk of group 1&2 is 126/1069 = 0.1179, the orginial overall churn 
risk is 323/5583 = 0.0578. Imporved 104%. */

/* The improvement may not seem to be impressive, however, if we increase the threshold of 
'estimate' when selecting risk groups, what would happen?*/


/*Sensitivity Analysis 1: Threshold, estimite > 3*/

/*select risk group where estimate >1 and p_value<0.05*/
proc sql;
create table cl.risk_group as 
select * from cl.results_v1
where estimate >3 and p_value < 0.05;
quit;

/*select risk group1 where lastlogin is missing*/
proc sql;
create table cl.risk_group1 as 
select * from cl.results_v1
where estimate >3 and p_value < 0.05 and lastlogin is missing and views is not missing;
quit;

/*select risk group2 where lastlogin is not missing*/
proc sql;
create table cl.risk_group2 as 
select * from cl.results_v1
where estimate >3 and p_value < 0.05 and lastlogin is not missing;
quit;

/*change format of group1*/
data cl.risk_group1;
set cl.risk_group1;
chi0_num = input(chi0,best8.);
views_num = input(views,best8.);
run;

/*drop the first obs in group 2 since all data is missing and change format*/
data cl.risk_group2;
set cl.risk_group2;
if chi0='.' and lastlogin = '.' then delete;
chi0_num = input(chi0,best8.);
views_num = input(views,best8.);
lastlogin_num = input(lastlogin,best8.);
run;

/*select all risk users for group1*/
proc sql;
create table cl.risk_users1 as
select distinct chi0_num,views_num,id,churn from cl.risk_group1 as a
inner join cl.risk_v5 as b
on a.chi0_num = b.cluster_chi0 and a.views_num = b.cluster_views
order by churn desc;
quit;

/*calculate churn risk*/
/* churn risk: 82/686*/

/*select all risk users for group2*/
proc sql;
create table cl.risk_users2 as
select distinct chi0_num,views_num,lastlogin_num,id,churn from cl.risk_group2 as a
inner join cl.risk_v5 as b
on a.chi0_num = b.cluster_chi0 and a.views_num = b.cluster_views and a.lastlogin_num=
b.cluster_lastlogin
order by churn desc;
quit;

/*calculate churn risk*/
/* churn risk: 36/177 overall: 118/863=0.1367*/
/*compared to original, improved 137%; compared to last time, improved 16%*/

/*Sensitivity Analysis 2: Threshold, estimite > 6*/

/*select risk group where estimate >6 and p_value<0.05*/
proc sql;
create table cl.risk_group as 
select * from cl.results_v1
where estimate >6 and p_value < 0.05;
quit;

/*select risk group1 where lastlogin is missing*/
proc sql;
create table cl.risk_group1 as 
select * from cl.results_v1
where estimate >6 and p_value < 0.05 and lastlogin is missing and views is not missing;
quit;

/*select risk group2 where lastlogin is not missing*/
proc sql;
create table cl.risk_group2 as 
select * from cl.results_v1
where estimate >6 and p_value < 0.05 and lastlogin is not missing;
quit;

/*change format of group1*/
data cl.risk_group1;
set cl.risk_group1;
chi0_num = input(chi0,best8.);
views_num = input(views,best8.);
run;

/*drop the first obs in group 2 since all data is missing and change format*/
data cl.risk_group2;
set cl.risk_group2;
if chi0='.' and lastlogin = '.' then delete;
chi0_num = input(chi0,best8.);
views_num = input(views,best8.);
lastlogin_num = input(lastlogin,best8.);
run;

/*select all risk users for group1*/
proc sql;
create table cl.risk_users1 as
select distinct chi0_num,views_num,id,churn from cl.risk_group1 as a
inner join cl.risk_v5 as b
on a.chi0_num = b.cluster_chi0 and a.views_num = b.cluster_views
order by churn desc;
quit;

/*calculate churn risk*/
/* churn risk: 2/8*/

/*select all risk users for group2*/
proc sql;
create table cl.risk_users2 as
select distinct chi0_num,views_num,lastlogin_num,id,churn from cl.risk_group2 as a
inner join cl.risk_v5 as b
on a.chi0_num = b.cluster_chi0 and a.views_num = b.cluster_views and a.lastlogin_num=
b.cluster_lastlogin
order by churn desc;
quit;

/*calculate churn risk*/
/* churn risk: 32/142   overall: 34/150 = 0.2267*/

/*compared to original, improved 292%; compared to last time, improved 65.8%*/
/*QUESTION3 CONCLUSION: The indentified risk group is 150/5583 = 2.5% of the total
population but contributed to over 10% of the overall churn.*/




/*QUESTION4: For the riskiest group identified in the previous part, what characteristics (other than
churn risk) separate them from the rest of QWE customers? What should customer
retention communications aimed at this group focus on? If different communications
should be used for different subgroups, make sure to estimate the importance of each
subgroup to QWE.*/

proc sql;
create table cl.riskuser as 
select id from cl.risk_users1
union
select id from cl.risk_users2;
quit;

proc sql;
select b.* from cl.riskuser as a
left join cl.risk_v5 as b
on a.id =b.id
order by churn desc;
quit;

/* according to the data, such high risk customers share these characteristics: 1.
they are not willing to provide a CHI 2. they are not willing to provide views.
3. days since last login is usually a month (e.g 31 days).


/*QUESTION5:It is estimated that an average ARPU (Average Revenue per User) for QWE is about $100
per month. An outbound call-based program is proposed to improve customer retention.
Each phone call (assuming right-party-connect is made) will cost QWE around $10. Can
your predictive model(s) be used to support such a program? If so, which customers
should be contacted and what financial returns can be expected (make sure you state
your assumptions).*/

/* develop a predictive model for the profit in next year to support decision making*/

/* ASSUMPTIONS:
1. No seasonalities of customer behaviours, that being said, we can use the churn rate
of Nov - Dec to model the churn across the year (churn rate is constant every month)
2. As stated in the case description, the company is growing very fast, we thus assume a
constant growth rate of customer base of 10% every month. For example: if the customer
amount by the end of November is 5000, churn is 6% 5000* 6% = 300, then the customer
by the end of December would be 5000-300+5000*10% = 5200.
3. Assume that the phonecall is very efficient and will reduce the risk of that customer 
to churn by 80% in next month.
4. Assume that customers of age 1-2 and >47 will not churn as suggested by previous model.

/* Financial impact results see Excel: financial_impact.xlsx*/