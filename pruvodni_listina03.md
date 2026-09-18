#### Průvodní listina

**Projekt SQL —** Michaela Novotná



**Znění zadání**- Naše oddělení se zabývá životní úrovní lidí. Kolegové připravili pět otázek
o tom, jak jsou pro běžného člověka dostupné základní potraviny. Já jsem měla
z databáze připravit data, ze kterých se na ty otázky dá odpovědět.



V databázi jsou hlavní dvě sady čísel a to mzdy(Kolik lidé v průměru vydělávají, rozdělené podle odvětví,
ve kterém pracují) a ceny potravin.(Kolik stojí chleba, mléko, máslo atd.)

Podle zadání jsem k tomu ještě přidala druhou tabulku s HDP, GINI koeficientem
a počtem obyvatel evropských států.

Porovnávat jsem mohla jen roky nad 2006.



poskládala jsem to ve třech krocích. Každý krok je vlastní poddotaz, hlavní `SELECT` z nich
jen vybere sloupce.

Databáze má mzdy po čtvrtletích. Udělala jsem z nich průměr
za celý rok, zvlášť pro každé odvětví. V tabulce mezd je jen kód odvětví,
takže jsem si přes `JOIN` přitáhla i jeho název.



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



Další byli ceny ty jsou v databázi po týdnech a mají jen datum, ne rok.
Rok jsem si z data vytáhla pomocí `EXTRACT` a zase udělala roční průměr,
tentokrát za každou potravinu.



(SELECT
EXTRACT(YEAR FROM p.date\_from) AS rok,
pc.name AS potravina,
pc.price\_value AS mnozstvi,
pc.price\_unit AS jednotka,
CAST(AVG(p.value) AS numeric(10,2)) AS cena\_kc
FROM czechia\_price p
JOIN czechia\_price\_category pc ON pc.code = p.category\_code
WHERE p.value IS NOT NULL
GROUP BY EXTRACT(YEAR FROM p.date\_from), pc.name, pc.price\_value, pc.price\_unit) AS ceny



pak jsem je spojila.



V tabulce s mzdami nejsou jen mzdy. Jsou tam
i počty zaměstnanců, a to ve stejném sloupci — proto filtr
`value\_type\_code = 5958`. A protože jsou mzdy vedené ve dvou variantách,
vybrala jsem jednu z nich pomocí `calculation\_code = 200`. Kdybych to
neudělala, průměrovala bych dvě různé věci dohromady a mzdy by vyšly nižší.



WHERE cp.value IS NOT NULL
AND cp.value\_type\_code = 5958    průměrná hrubá mzda na zaměstnance
AND cp.calculation\_code = 200      přepočtený počet zaměstnanců



měření meziroční mzdy. spojila jsem tabulku, kde `t1` je starší rok a `t2` ten následující.
Rozdíl se pak spočítá jako podíl obou hodnot.



FROM (SELECT DISTINCT rok, odvetvi, mzda\_kc
FROM t\_michaela\_novotna\_project\_SQL\_primary\_final) AS t1
JOIN (SELECT DISTINCT rok, odvetvi, mzda\_kc
FROM t\_michaela\_novotna\_project\_SQL\_primary\_final) AS t2
ON t2.odvetvi = t1.odvetvi
AND t2.rok = t1.rok + 1

ROUND(100 \* (t2.mzda\_kc / t1.mzda\_kc - 1), 2) AS zmena\_pct



Jak měřit zdražování. Nejdřív mě napadlo spočítat průměrnou cenu v korunách
a porovnávat ji mezi roky. Pak jsem si všimla, že v datech je kilo másla
i půllitr piva. Průměr z toho by nic neznamenal. Počítám proto, o kolik procent
zdražila každá potravina zvlášť, a teprve ty procenta průměruji.



ROUND(AVG(100 \* (t2.cena\_kc / t1.cena\_kc - 1)), 2) AS prumerny\_mezirocni\_rust



Odduplikování. Ve výsledné tabulce se mzda opakuje u každé z 27 potravin
a cena u každého z 19 odvětví. Než začnu počítat, musím proto vybrat jen
jedinečné řádky pomocí `SELECT DISTINCT`.



(SELECT DISTINCT rok, potravina, cena\_kc
FROM t\_michaela\_novotna\_project\_SQL\_primary\_final)



Poslední rok u otázky 5. Pro rok 2018 neexistuje „následující rok".
Obyčejný `JOIN` by ho z výsledku vyhodil, proto jsem u něj použila `LEFT JOIN` —
rok zůstane v tabulce a chybějící hodnota je prostě prázdná.



LEFT JOIN (SELECT rok, ... FROM t\_michaela\_novotna\_project\_SQL\_primary\_final
GROUP BY rok) AS t3
ON t3.rok = t2.rok + 1

