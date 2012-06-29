#!perl -T

use Test::More;
use TenorSAX::Source::Troff;
use TenorSAX::Output::Text;

sub run_test {
	my $request = shift;
	my $text = "";
	my $output = TenorSAX::Output::Text->new(Output => \$text);
	my $parser = TenorSAX::Source::Troff->new(Handler => $output);

	my $code = <<EOM;
.if ddo \\{
.if dtenorsax .do tenorsax ext 1
.\\}
.de ST
.ie d\\\\\$1 implemented
.el missing
.br
..
.ST $request
EOM
	$parser->parse_string($code);
	is($text, "implemented", "request $request is implemented");
}

my @implemented = ();
my @unimplemented = qw/
do
xflag

lc_ctype
ps
fzoom
ss
cs
bd
ft
fp
fps
feature
fallback
hidechar
spacewidth
fspacewidth

pl
papersize
mediasize
cropat
trimat
bleedat
bp
pn
po
ne
mk
rt

br
brp
fi
nf
ad
na
padj
ce
rj
brnl
brpnl
minss
letadj
sentchar
transchar
track
kern
fkern
kernpair
kernafter
kernbefore
lhang
rhang

vs
ls
sp
sv
os
ns
rs

ll
in
ti
pshape

de
am
ds
as
lds
substring
length
index
chop
rm
rn
di
da
box
boxa
unformat
asciify
wh
ch
dwh
dch
dt
vpt
it
itc
return
shift
als
blm
em
recursionlimit

nr
nrf
lnr
lnrf
af
rr
rnn
aln

ta
tc
lc
fc

ec
eo
ecs
ecr
lg
flig
fdeferlig
ul
cu
uf
cc
c2
tr
trin
trnt
ftr
char
fchar
rchar
output

nh
hy
hylang
shc
hcode
hylen
hlm
hypp
breakchar
nhychar
hc
hw

tl
pc
lt

nm
nn

if
ie
while
break
continue

ev
evc

rd
ex

so
pso
nx
sy
pi
cf
open
opena
write
writec
writem
close

mc
lpfx
tm
tmc
nop
ab
ig
lf
pm
fl

warn
spreadwarn
errprint
watch
unwatch
watchlength
watchn
unwatchn

CL

psbb
BP
EP
PI

cp
mso

tenorsax
namespace
start
end
/;

plan tests => @implemented + @unimplemented;

foreach my $request (@implemented) {
	run_test($request);
}

foreach my $request (@unimplemented) {
	TODO: {
		local $TODO = "not yet implemented";
		run_test($request);
	}
}
