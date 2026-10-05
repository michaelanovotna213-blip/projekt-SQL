#### Průvodní listina

**Projekt SQL**- Michaela Novotná

Úvod
Zadáním bylo zjistit, jak jsou pro běžného člověka dostupné základní potraviny
a jestli se to v čase zlepšuje nebo zhoršuje. V databázi jsou k tomu dvě sady čísel. Mzdy — kolik lidé v průměru
vydělávají, rozdělené podle odvětví, ve kterém pracují. A ceny potravin — kolik stojí chleba, mléko, máslo atd.
K projektu jsem využila Claude ai aby mi objasnila jak se věci mají. Mzdy jsou v databázi za roky 2000 až 2021. Ceny potravin jen 2006 až 2018 takže můžu porovnávat jenom tyto roky. Do skriptu jsem ta čísla nepsala ručně. Spojení se dělá přes rok, takže chybějící roky samy vypadnou.

ON ceny.rok = mzdy.rok

Mzdy jsou po čtvrtletích. Udělala jsem z nich roční průměr, zvlášť pro každé odvětví. V tabulce je jen kód odvětví, přes `JOIN` jsem přitáhla název. Ve sloupci `value` nejsou jen mzdy, ale i počty zaměstnanců. Proto filtr 

`value\_type\_code = 5958`. Mzdy jsou navíc ve dvou variantách, jednu vybírá `calculation\_code = 200`.

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

 Výzkumné otázky a odpovědi

 1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?

Ne, nerostou všude. Ze 19 odvětví jich 16 zaznamenalo alespoň jeden
meziroční pokles mzdy. Nejvíc poklesů má třeba těžba a dobývání (4 roky), dále výroba a rozvod
elektřiny, plynu a tepla (3 roky).

Celé období bez jediného poklesu prošla jen tři odvětví: zpracovatelský
průmysl, zdravotní a sociální péče a ostatní činnosti.

---

2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období?

Za průměrnou mzdu se v roce 2018 koupilo 1 641,6 litru mléka a 1 342,2 kg chleba oproti 1 437,2 litru a 1 287,5 kg v roce 2006

---

 3. Která kategorie potravin zdražuje nejpomaleji?

Nejnižší procentuální nárůst je u krystalového cukru  Ve skutečnosti nezdražuje vůbec — za sledované období
průměrně zlevňoval o 1,92 % ročně.

---

4. Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

ne neexistuje, všechny nárůsty jsou menší než 10%

---

5. Má výška HDP vliv na změny ve mzdách a cenách potravin?

Na mzdách se změna projeví cca s ročním zpožděním, na cenách potravin skoro vůbec.

---

Závěr

Dostupnost základních potravin se mezi lety 2006 a 2018 zlepšila. Mzdy rostly rychleji než ceny potravin, takže si za průměrnou výplatu lze koupit víc jídla než na začátku období. U mléka je to o 14 % víc, u chleba o 4 %. Zlepšení ale nebylo plynulé. V 16 z 19 odvětví mzda aspoň jednou meziročně klesla a rok 2013 byl pro zaměstnance nejhorší. Jednotlivé potraviny zdražovali a zlevňovaly různě . Cukr a rajčata za sledované
období zlevňovaly, papriky a máslo zdražovaly o víc než 6 % ročně. Růst HDP se promítá do mezd, ale až s ročním odstupem. Na ceny potravin vliv nemá.



