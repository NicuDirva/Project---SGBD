create or replace procedure pct6
    (n number)
IS
    type nume_jucator is varray(100) of persoana.nume%type;
    v_nume nume_jucator := nume_jucator();
    type id_echipe is table of number index by pls_integer;
    v_id_echipe id_echipe;
    nume_echipa echipa.denumire%TYPE;
    nr number;
BEGIN
    select * bulk collect into v_id_echipe
    from (select e.id_echipa
            from echipa e, sponsor s, contract c
            where e.data_infiintarii > '01-JAN-1900' and e.id_echipa = c.id_echipa and c.id_sponsor=s.id_sponsor 
            and s.numar_echipe_sponsorizate > 2
            order by e.data_infiintarii)
    where rownum < n+1;

    for i in v_id_echipe.first .. v_id_echipe.last loop  
        select denumire into nume_echipa
        from echipa
        where id_echipa = v_id_echipe(i);
        
        DBMS_OUTPUT.PUT_LINE('Jucatori din echipa ' || nume_echipa || ':');
        
        select * bulk collect into v_nume
        from(select p.nume
            from persoana p, jucator j, echipa e
            where p.id_persoana = j.id_persoana and e.id_echipa = j.id_echipa and e.id_echipa = v_id_echipe(i));
            
        select count(*) into nr
        from(select p.nume
            from persoana p, jucator j, echipa e
            where p.id_persoana = j.id_persoana and e.id_echipa = j.id_echipa and e.id_echipa = v_id_echipe(i));
        
        if nr != 0 then
            for j in v_nume.first .. v_nume.last loop
                DBMS_OUTPUT.PUT_LINE(v_nume(j));
            end loop;
        else
            DBMS_OUTPUT.PUT_LINE('In echipa nu exista jucatori inscrisi!');
        end if;
    end loop;
end;
/

create or replace procedure pct7
IS
    cursor c1 is
        select post.denumire_post, floor(avg(salariu))
        from post
        group by post.denumire_post;
    nume_jucator post.denumire_post%TYPE;
    sal post.salariu%TYPE;
        
BEGIN
    for c1 in(select denumire_post as nume_post, floor(avg(salariu)) as medie_sal
        from post
        group by denumire_post)
    
    loop
        declare
            cursor c2(nume_post post.denumire_post%TYPE, medie_sal post.salariu%TYPE) IS
                select p.nume, o.salariu
                from persoana p, post o, jucator j
                where p.id_persoana = j.id_persoana and j.id_post = o.id_post and o.denumire_post = nume_post and o.salariu > medie_sal;
        begin
            DBMS_OUTPUT.PUT_LINE('Pe postul ' || c1.nume_post || ' este media salariilor ' || c1.medie_sal || ' si se incadreaza:');
            open c2(c1.nume_post, c1.medie_sal);
            loop
            
                fetch c2 into nume_jucator, sal;
                exit when c2%notfound;
                
                DBMS_OUTPUT.PUT_LINE('Nume: ' || nume_jucator || '  Salariu: ' || sal);
            
            end loop;
            close c2;
        end;
    
    end loop;
END;

create or replace function jucatori_activi(id echipa.id_echipa%TYPE)
    return number
AS
    cnt number;
BEGIN
    select count(*) into cnt
    from echipa e, jucator j
    where e.id_echipa = j.id_echipa and e.id_echipa = id;
    
    return cnt;
END;

create or replace function pct8(sponsorizare number)
    return number
IS
    type id is varray(100) of echipa.id_echipa%TYPE;
    id_echipe_p id := id();
    id_e echipa.id_echipa%TYPE;
    maxi number := -1;
    curent number;
    no_data EXCEPTION;
    too_many EXCEPTION;
BEGIN
    select e.id_echipa bulk collect into id_echipe_p
    from echipa e, contract c, sponsor s
    where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and s.buget_investit > sponsorizare 
    and lower(to_char(c.data_inceperii_contractului, 'mon')) = 'jun';
    
    select count(*) into curent
    from echipa e, contract c, sponsor s
    where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and s.buget_investit > sponsorizare 
    and lower(to_char(c.data_inceperii_contractului, 'mon')) = 'jun';
    
    if curent != 0 then
        for i in id_echipe_p.first .. id_echipe_p.last loop
            curent := jucatori_activi(id_echipe_p(i));
            if curent > maxi then
                maxi := curent;
            end if;
        end loop;
    else
        RAISE no_data;
    end if;

    select count(e.id_echipa) into curent
    from echipa e, contract c, sponsor s
    where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and s.buget_investit > sponsorizare
    and lower(to_char(c.data_inceperii_contractului, 'mon')) = 'jun';

    if curent = 1 then
        select id_echipa into id_e
        from echipa
        where id_echipa in (select e.id_echipa
                            from echipa e, contract c, sponsor s
                            where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and s.buget_investit > sponsorizare
                            and lower(to_char(c.data_inceperii_contractului, 'mon')) = 'jun')
        and jucatori_activi(id_echipa) = maxi;
    
        return id_e;
    else
        RAISE too_many;
    end if;
EXCEPTION
    when too_many then
        DBMS_OUTPUT.PUT_LINE('Exista mai multe echipe care indeplicesc cerintele!');
        return -1;
    when no_data then
        DBMS_OUTPUT.PUT_LINE('Nu exista echipe care indeplicesca cerintele!');
        return -2;
    when others then
        DBMS_OUTPUT.PUT_LINE('Alta eroare');
        return -3;
end pct8;

create or replace procedure pct9
    (x IN number)
IS
    id_e echipa.id_echipa%TYPE;
    minor EXCEPTION;
    varsta number;

BEGIN

    select distinct e.id_echipa into id_e
    from echipa e, contract c, sponsor s, galerie g, campionat m, planificare l
    where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and lower(s.nume_sponsor) = 'city insurance'
    and g.id_echipa = e.id_echipa and g.numar_participanti > x and (e.id_echipa = l.id_echipa1 or e.id_echipa = l.id_echipa2) 
    and l.id_campionat = m.id_campionat and m.tara_desfasurare = 'Romania';
    
    for c in(select p.nume as nume, p.data_nasterii as an_nastere
            from persoana p, echipa e, jucator j
            where e.id_echipa = id_e and j.id_persoana = p.id_persoana and j.id_echipa = e.id_echipa
            order by 2 desc)
    loop
        select ROUND(MONTHS_BETWEEN(SYSDATE, c.an_nastere))/12 into varsta
        from dual;
        if varsta > 18 then
            DBMS_OUTPUT.PUT_LINE('Nume: ' || c.nume || ' Data nasterii: ' || c.an_nastere);
        else
            RAISE minor;
        end if;
    end loop;
    
EXCEPTION
    when no_data_found then
        DBMS_OUTPUT.PUT_LINE('Nu exista echipe care sa indeplineasca cerintele!');
    when too_many_rows then
        DBMS_OUTPUT.PUT_LINE('Exista mai multe echipe care indeplinesc cerintele!');
    when minor then
        DBMS_OUTPUT.PUT_LINE('Jucatorul nu are varsta legala pentru a semna un contract!');
    when others then
        DBMS_OUTPUT.PUT_LINE('Alta eroare');
END pct9;
/

create or replace package pct13 as
    procedure pct6(n number);
    procedure pct7;
    function jucatori_activi(id echipa.id_echipa%TYPE)
    	return number;
    function pct8(sponsorizare number)
        return number;
    procedure pct9(x IN number);
    procedure modificare_echipa(id_e echipa.id_echipa%TYPE, x number);
end pct13;
/
create or replace package body pct13 as

    procedure pct6
        (n number)
    IS
        type nume_jucator is varray(100) of persoana.nume%type;
        v_nume nume_jucator := nume_jucator();
        type id_echipe is table of number index by pls_integer;
        v_id_echipe id_echipe;
        nume_echipa echipa.denumire%TYPE;
        nr number;
    BEGIN
        select * bulk collect into v_id_echipe
        from (select e.id_echipa
                from echipa e, sponsor s, contract c
                where e.data_infiintarii > '01-JAN-1900' and e.id_echipa = c.id_echipa and c.id_sponsor=s.id_sponsor 
                and s.numar_echipe_sponsorizate > 2
                order by e.data_infiintarii)
        where rownum < n+1;
    
        for i in v_id_echipe.first .. v_id_echipe.last loop  
            select denumire into nume_echipa
            from echipa
            where id_echipa = v_id_echipe(i);
            
            DBMS_OUTPUT.PUT_LINE('Jucatori din echipa ' || nume_echipa || ':');
            
            select * bulk collect into v_nume
            from(select p.nume
                from persoana p, jucator j, echipa e
                where p.id_persoana = j.id_persoana and e.id_echipa = j.id_echipa and e.id_echipa = v_id_echipe(i));
                
            select count(*) into nr
            from(select p.nume
                from persoana p, jucator j, echipa e
                where p.id_persoana = j.id_persoana and e.id_echipa = j.id_echipa and e.id_echipa = v_id_echipe(i));
            
            if nr != 0 then
                for j in v_nume.first .. v_nume.last loop
                    DBMS_OUTPUT.PUT_LINE(v_nume(j));
                end loop;
            else
                DBMS_OUTPUT.PUT_LINE('In echipa nu exista jucatori inscrisi!');
            end if;
        end loop;
    end;
    
    procedure pct7
    IS
        cursor c1 is
            select post.denumire_post, floor(avg(salariu))
            from post
            group by post.denumire_post;
        nume_jucator post.denumire_post%TYPE;
        sal post.salariu%TYPE;
            
    BEGIN
        for c1 in(select denumire_post as nume_post, floor(avg(salariu)) as medie_sal
            from post
            group by denumire_post)
        
        loop
            declare
                cursor c2(nume_post post.denumire_post%TYPE, medie_sal post.salariu%TYPE) IS
                    select p.nume, o.salariu
                    from persoana p, post o, jucator j
                    where p.id_persoana = j.id_persoana and j.id_post = o.id_post and o.denumire_post = nume_post and o.salariu > medie_sal;
            begin
                DBMS_OUTPUT.PUT_LINE('Pe postul ' || c1.nume_post || ' este media salariilor ' || c1.medie_sal || ' si se incadreaza:');
                open c2(c1.nume_post, c1.medie_sal);
                loop
                
                    fetch c2 into nume_jucator, sal;
                    exit when c2%notfound;
                    
                    DBMS_OUTPUT.PUT_LINE('Nume: ' || nume_jucator || '  Salariu: ' || sal);
                
                end loop;
                close c2;
            end;
        
        end loop;
    END;

    function jucatori_activi(id echipa.id_echipa%TYPE)
    	return number
    AS
    	cnt number;
    BEGIN
    	select count(*) into cnt
    	from echipa e, jucator j
    	where e.id_echipa = j.id_echipa and e.id_echipa = id;
    
    	return cnt;
    END;

    function pct8(sponsorizare number)
        return number
    IS
        type id is varray(100) of echipa.id_echipa%TYPE;
        id_echipe_p id := id();
        id_e echipa.id_echipa%TYPE;
        maxi number := -1;
        curent number;
        no_data EXCEPTION;
    BEGIN
        select e.id_echipa bulk collect into id_echipe_p
        from echipa e, contract c, sponsor s
        where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and s.buget_investit > sponsorizare 
        and lower(to_char(c.data_inceperii_contractului, 'mon')) = 'jun';
        
        select count(*) into curent
        from echipa e, contract c, sponsor s
        where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and s.buget_investit > sponsorizare 
        and lower(to_char(c.data_inceperii_contractului, 'mon')) = 'jun';
        
        if curent != 0 then
            for i in id_echipe_p.first .. id_echipe_p.last loop
                curent := jucatori_activi(id_echipe_p(i));
                if curent > maxi then
                    maxi := curent;
                end if;
            end loop;
        else
            RAISE no_data;
        end if;
    
        select id_echipa into id_e
        from echipa
        where id_echipa in (select e.id_echipa
                            from echipa e, contract c, sponsor s
                            where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and s.buget_investit > sponsorizare
                            and lower(to_char(c.data_inceperii_contractului, 'mon')) = 'jun')
        and jucatori_activi(id_echipa) = maxi;
        
        return id_e;
    EXCEPTION
        when too_many_rows then
            DBMS_OUTPUT.PUT_LINE('Exista mai multe echipe care indeplicesc cerintele!');
            return -1;
        when no_data then
            DBMS_OUTPUT.PUT_LINE('Nu exista echipe care indeplicesca cerintele!');
            return -2;
        when others then
            DBMS_OUTPUT.PUT_LINE('Alta eroare');
            return -3;
    end pct8;
    
    procedure pct9
    	(x IN number)
    IS
    	id_e echipa.id_echipa%TYPE;
    	minor EXCEPTION;
    	varsta number;

    BEGIN

    	select distinct e.id_echipa into id_e
    	from echipa e, contract c, sponsor s, galerie g, campionat m, planificare l
    	where e.id_echipa = c.id_echipa and c.id_sponsor = s.id_sponsor and lower(s.nume_sponsor) = 'city insurance'
    	and g.id_echipa = e.id_echipa and g.numar_participanti > x and (e.id_echipa = l.id_echipa1 or e.id_echipa = l.id_echipa2) 
    	and l.id_campionat = m.id_campionat and m.tara_desfasurare = 'Romania';
    
    	for c in(select p.nume as nume, p.data_nasterii as an_nastere
            	from persoana p, echipa e, jucator j
            	where e.id_echipa = id_e and j.id_persoana = p.id_persoana and j.id_echipa = e.id_echipa
            	order by 2 desc)
    	loop
        	select ROUND(MONTHS_BETWEEN(SYSDATE, c.an_nastere))/12 into varsta
        	from dual;

        	if varsta > 18 then
            		DBMS_OUTPUT.PUT_LINE('Nume: ' || c.nume || ' Data nasterii: ' || c.an_nastere);
        	else
            		RAISE minor;
        	end if;
    	end loop;
    
    EXCEPTION
    	when no_data_found then
        	DBMS_OUTPUT.PUT_LINE('Nu exista echipe care sa indeplineasca cerintele!');
    	when too_many_rows then
        	DBMS_OUTPUT.PUT_LINE('Exista mai multe echipe care indeplinesc cerintele!');
    	when minor then
        	DBMS_OUTPUT.PUT_LINE('Jucatorul nu are varsta legala pentru a semna un contract!');
    	when others then
        	DBMS_OUTPUT.PUT_LINE('Alta eroare');
    END pct9;


    procedure modificare_echipa(id_e echipa.id_echipa%TYPE, 
                                                x number)
    IS
    BEGIN
        update echipa
        set numar_jucatori = numar_jucatori + x
        where id_echipa = id_e;
    END;
end pct13;
/

