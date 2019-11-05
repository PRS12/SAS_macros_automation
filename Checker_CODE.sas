
options mprint mlogic;
%macro check_code(data);
proc sql;
select distinct(count(LOY_CARD_NUMBER)) as target into: TRG
from whouse.member a
inner join
&data b
on a.LOY_CARD_NUMBER eq  b.CARD_NUMBER
where a.bad_email eq 1
or a.bad_mobile_phone eq 1
or a.IS_DELETED eq 1
or a.IS_MEMBER_DISABLED eq 1
or sourced_association_id eq 64
or member_card_type_id  in (167,166) ;quit;
%put If TARGET has the value &TRG (0 then success, else fail);
%mend check_code;



