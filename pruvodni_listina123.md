#### Průvodní listina

**Projekt SQL**- Michaela Novotná



K projektu jsem využila Claude ai aby mi objasnila jak se věci mají.

Mzdy jsou v databázi za roky 2000 až 2021. Ceny potravin jen 2006 až 2018 takže můžu porovnávat jenom tyto roky.

Do skriptu jsem ta čísla nepsala ručně. Spojení se dělá přes rok, takže chybějící roky samy vypadnou.


ON ceny.rok = mzdy.rok




Mzdy jsou po čtvrtletích. Udělala jsem z nich roční průměr, zvlášť pro každé odvětví. V tabulce je jen kód odvětví, přes `JOIN` jsem přitáhla název. Ve sloupci `value` nejsou jen mzdy, ale i počty zaměstnanců. Proto filtr `value\_type\_code = 5958`. Mzdy jsou navíc ve dvou variantách, jednu vybírá `calculation\_code = 200`.


(SELECT
     cp.payroll\_year AS rok,
     ib.name AS odvetvi,
     CAST(AVG(cp.value) AS numeric(10,2)) AS mzda\_kc
 FROM czechia\_payroll cp
 JOIN czechia\_payroll\_industry\_branch ib ON ib.code = cp.industry\_branch\_code
 WHERE cp.value IS NOT NULL
   AND cp.value\_type\_code = 5958
   AND cp.calculation\_code = 200
 GROUP BY cp.payroll\_year, ib.name) AS mzdy


Ceny jsou po týdnech a mají jen datum, ne rok. Rok jsem vytáhla pomocí `date\_part`. Pak zase roční průměr, tentokrát za každou potravinu.


(SELECT
     date\_part('year', p.date\_from) AS rok,
     pc.name AS potravina,
     pc.price\_value AS mnozstvi,
     pc.price\_unit AS jednotka,
     CAST(AVG(p.value) AS numeric(10,2)) AS cena\_kc
 FROM czechia\_price p
 JOIN czechia\_price\_category pc ON pc.code = p.category\_code
 WHERE p.value IS NOT NULL
 GROUP BY date\_part('year', p.date\_from), pc.name, pc.price\_value, pc.price\_unit) AS ceny


Obojí jsem spojila podle roku. Výsledek má 6 498 řádků — 13 let × 19 odvětví × 27 potravin. Na pořadí záleží, každý pod dotaz nejdřív spočítá svůj průměr.



Pro meziroční mzdu tabulku spojím samu se sebou. `t1` je starší rok, `t2` následující.


FROM (SELECT DISTINCT rok, odvetvi, mzda\_kc
      FROM t\_michaela\_novotna\_project\_SQL\_primary\_final) AS t1
JOIN (SELECT DISTINCT rok, odvetvi, mzda\_kc
      FROM t\_michaela\_novotna\_project\_SQL\_primary\_final) AS t2
  ON t2.odvetvi = t1.odvetvi
 AND t2.rok = t1.rok + 1


Změnu pak spočítám jako podíl obou hodnot.



ROUND(100 \* (t2.mzda\_kc / t1.mzda\_kc - 1), 2) AS zmena\_pct


U zdražování počítám procento zvlášť u každé potraviny a teprve ty procenta průměruji.


ROUND(AVG(100 \* (t2.cena\_kc / t1.cena\_kc - 1)), 2) AS prumerny\_mezirocni\_rust


Ve výsledné tabulce se mzda opakuje proto před počítáním vybírám jen samostatné řádky.


(SELECT DISTINCT rok, potravina, cena\_kc
 FROM t\_michaela\_novotna\_project\_SQL\_primary\_final)




U poslední otázky potřebuju stejné mezivýpočty čtyřikrát: růst mezd a růst cen,
pokaždé pro stejný rok i pro rok následující. Proto jsem je pojmenovala
blokem `WITH`. Bez něj by se ty samé poddotazy v dotazu opakovaly čtyřikrát.

Pro rok 2018 navíc neexistuje následující rok. Obyčejný `JOIN` by ho vyhodil,
proto `LEFT JOIN`. Rok zůstane a chybějící hodnota je prázdná.


FROM hdp AS h
LEFT JOIN mzdy AS m  ON m.rok  = h.rok
LEFT JOIN ceny AS c  ON c.rok  = h.rok
LEFT JOIN mzdy AS m2 ON m2.rok = h.rok + 1
LEFT JOIN ceny AS c2 ON c2.rok = h.rok + 1


