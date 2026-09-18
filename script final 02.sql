/*primární tabulka pro data mezd a cen potravin za Českou republiku sjednocených na totožné porovnatelné období – společné roky*/
CREATE TABLE t_michaela_novotna_project_SQL_primary_final  AS
select
    mzdy.rok,
    mzdy.odvetvi,
    mzdy.mzda_kc,
    ceny.potravina,
    ceny.mnozstvi,
    ceny.jednotka,
    ceny.cena_kc 
FROM
    (SELECT
         cp.payroll_year AS rok,
         ib.name AS odvetvi,
         CAST(AVG(cp.value) AS numeric(10,2)) AS mzda_kc
     FROM czechia_payroll cp
     JOIN czechia_payroll_industry_branch ib ON ib.code = cp.industry_branch_code
     WHERE cp.value IS NOT NULL
       AND cp.value_type_code = 5958
     GROUP BY cp.payroll_year, ib.name) AS mzdy
JOIN
    (SELECT
         EXTRACT(YEAR FROM p.date_from) AS rok,
         pc.name AS potravina,
         pc.price_value AS mnozstvi,
         pc.price_unit AS jednotka,
         CAST(AVG(p.value) AS numeric(10,2)) AS cena_kc
     FROM czechia_price p
     JOIN czechia_price_category pc ON pc.code = p.category_code
     WHERE p.value IS NOT NULL
     GROUP BY EXTRACT(YEAR FROM p.date_from), pc.name, pc.price_value, pc.price_unit) AS ceny
ON ceny.rok = mzdy.rok;

/* sekundární tabulka pro dodatečná data o dalších evropských státech*/
CREATE TABLE "t_michaela_novotna_project_SQL_secondary_final" AS
SELECT
    c.country AS stat,
    e.year AS rok,
    e.gdp AS hdp,
    e.gini,
    e.population AS populace
FROM countries c
JOIN economies e ON e.country = c.country
WHERE c.continent = 'Europe'
  AND e.year BETWEEN 2006 AND 2018;

/* otázka 1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
 * odpověď - ne nerostou všude, bez poklesu jen Zpracovatelský průmysl, Zdravotní a sociální péče a Ostatní činnosti.*/


SELECT
    t1.odvetvi,
    t2.rok,
    t1.mzda_kc                                  AS mzda_predchozi_rok,
    t2.mzda_kc                                  AS mzda_aktualni_rok,
    ROUND(100 * (t2.mzda_kc / t1.mzda_kc - 1), 2) AS zmena_pct
FROM (SELECT DISTINCT rok, odvetvi, mzda_kc
      FROM t_michaela_novotna_project_SQL_primary_final ) AS t1
JOIN ( SELECT DISTINCT rok, odvetvi, mzda_kc
      FROM t_michaela_novotna_project_SQL_primary_final ) AS t2
  ON t2.odvetvi = t1.odvetvi
 AND t2.rok = t1.rok + 1
WHERE t2.mzda_kc < t1.mzda_kc
ORDER BY t1.odvetvi, t2.rok;

SELECT
    t1.odvetvi,
    COUNT(*) AS pocet_poklesu
FROM (SELECT DISTINCT rok, odvetvi, mzda_kc
      FROM t_michaela_novotna_project_SQL_primary_final ) AS t1
JOIN (SELECT DISTINCT rok, odvetvi, mzda_kc
      FROM t_michaela_novotna_project_SQL_primary_final ) AS t2
  ON t2.odvetvi = t1.odvetvi
 AND t2.rok = t1.rok + 1
WHERE t2.mzda_kc < t1.mzda_kc
GROUP BY t1.odvetvi
ORDER BY pocet_poklesu DESC;

/* otázka 2 Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd? 
 * odpověď- Za průměrnou mzdu se v roce 2018 koupilo 1 641,6 litru mléka a 1 342,2 kg chleba oproti 1 437,2 litru a 1 287,5 kg v roce 2006*/

SELECT
    ceny.rok,
    ceny.potravina,
    ceny.jednotka,
    mzdy.mzda_kc,
    ceny.cena_kc,
    ROUND(mzdy.mzda_kc / ceny.cena_kc, 1) AS mnozstvi_za_mzdu
FROM
    (SELECT rok, ROUND(AVG(mzda_kc), 2) AS mzda_kc
     FROM (SELECT DISTINCT rok, odvetvi, mzda_kc
           FROM t_michaela_novotna_project_SQL_primary_final ) AS x
     GROUP BY rok) AS mzdy
JOIN
    (SELECT DISTINCT rok, potravina, jednotka, cena_kc
     FROM t_michaela_novotna_project_SQL_primary_final
     WHERE potravina IN ('Mléko polotučné pasterované',
                         'Chléb konzumní kmínový')) AS ceny
    ON ceny.rok = mzdy.rok
WHERE ceny.rok IN (2006, 2018)
ORDER BY ceny.potravina, ceny.rok;

/*otázka 3 Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst
 * odpovědˇ- nejnižší procentuální nárůst je u krystalového cukru */

SELECT
    t1.potravina,
    ROUND(AVG(100 * (t2.cena_kc / t1.cena_kc - 1)), 2) AS prumerny_mezirocni_rust
FROM (SELECT DISTINCT rok, potravina, cena_kc
      FROM t_michaela_novotna_project_SQL_primary_final ) AS t1
JOIN (SELECT DISTINCT rok, potravina, cena_kc
      FROM t_michaela_novotna_project_SQL_primary_final) AS t2
    ON t2.potravina = t1.potravina
   AND t2.rok = t1.rok + 1
GROUP BY t1.potravina
ORDER BY prumerny_mezirocni_rust;

/* otázka 4 Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
 * odpověď- ne neexistuje, všechny nárůsty jsou menší než 10%*/

SELECT
    t2.rok,
    ROUND(100 * (t2.prumerna_mzda / t1.prumerna_mzda - 1), 2) AS rust_mezd,
    ROUND(100 * (t2.prumerna_cena / t1.prumerna_cena - 1), 2) AS rust_cen,
    ROUND(100 * (t2.prumerna_cena / t1.prumerna_cena - 1)
        - 100 * (t2.prumerna_mzda / t1.prumerna_mzda - 1), 2) AS rozdil
FROM (SELECT rok, AVG(mzda_kc) AS prumerna_mzda, AVG(cena_kc) AS prumerna_cena
      FROM t_michaela_novotna_project_SQL_primary_final GROUP BY rok) AS t1
JOIN (SELECT rok, AVG(mzda_kc) AS prumerna_mzda, AVG(cena_kc) AS prumerna_cena
      FROM t_michaela_novotna_project_SQL_primary_final GROUP BY rok) AS t2
    ON t2.rok = t1.rok + 1
ORDER BY rozdil DESC;

/* otázka 5 Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo následujícím roce výraznějším růstem?
 * odpověď - na mzdách se změna projeví cca s ročním zpožděním, na cenách potravin skoro vůbec.
 */
SELECT
    t2.rok,
    ROUND(CAST(100 * (hdp2.hdp / hdp1.hdp - 1) AS numeric), 2) AS rust_hdp,
    ROUND(100 * (t2.prumerna_mzda / t1.prumerna_mzda - 1), 2) AS mzdy_stejny_rok,
    ROUND(100 * (t2.prumerna_cena / t1.prumerna_cena - 1), 2) AS ceny_stejny_rok,
    ROUND(100 * (t3.prumerna_mzda / t2.prumerna_mzda - 1), 2) AS mzdy_dalsi_rok,
    ROUND(100 * (t3.prumerna_cena / t2.prumerna_cena - 1), 2) AS ceny_dalsi_rok
FROM (SELECT rok, AVG(mzda_kc) AS prumerna_mzda, AVG(cena_kc) AS prumerna_cena
      FROM t_michaela_novotna_project_SQL_primary_final GROUP BY rok) AS t1
JOIN (SELECT rok, AVG(mzda_kc) AS prumerna_mzda, AVG(cena_kc) AS prumerna_cena
      FROM t_michaela_novotna_project_SQL_primary_final GROUP BY rok) AS t2
    ON t2.rok = t1.rok + 1
LEFT JOIN (SELECT rok, AVG(mzda_kc) AS prumerna_mzda, AVG(cena_kc) AS prumerna_cena
           FROM t_michaela_novotna_project_SQL_primary_final GROUP BY rok) AS t3
    ON t3.rok = t2.rok + 1
JOIN "t_michaela_novotna_project_SQL_secondary_final" AS hdp1
    ON hdp1.rok = t1.rok AND hdp1.stat = 'Czech Republic'
JOIN "t_michaela_novotna_project_SQL_secondary_final" AS hdp2
    ON hdp2.rok = t2.rok AND hdp2.stat = 'Czech Republic'
ORDER BY t2.rok;


