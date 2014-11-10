#!/usr/bin/perl

package RegolfDB;
use strict;
use warnings;
require Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( word_grab word_generate @good @bad $wordlist $roundwordlist );

our $wordlist = '/usr/share/dict/words'; # This is our big dictionary of words to pick from. ideally we will make the words similar in some way.
our $roundwordlist;
our @good = ();
our @bad = ();  # two lists

my $usefilters = 0;
my @filters = ();
if($usefilters){
  @filters = ('(\w{3}).*\1', '^_0.*_0$', '^[qwertyuiopasdfghjkl]+$', '^[a-f]+$', '=', '_0_1_2', '^(.)(.)(.?)(.?)(.?)(.?).?\6\5\4\3\2\1$');
} else {
  @filters = ('.');
}
my @characters = ("a".."z");

sub word_grab {
  my ($self, $amt) = @_;
  my @words = ();
  my $f = undef;
  while(@words <= ($amt * 2)){
    @words = ();
    $f = $filters[rand @filters];
    if( $f eq "="){
      my $num = int(rand(7)+2);
      print STDOUT $num;
      for my $n(1000..100000){
        push @words, $n if $n % $num == 0;
      }
    } else {
      for my $j (0..9) {
        my $letter = $characters[rand @characters];
        $f =~ s/_$j/$letter/g;
      }
      print STDOUT "$f\n";
      open WORDS, '<', $roundwordlist or die "Cannot open $roundwordlist:$!";
      while(my $word = <WORDS>){
        chomp($word);
        push @words, $word if $word =~ /^[a-z]{2,}$/i and $word =~ /$f/i;  # filter out names with capitol letters as well as apostrophes and stuff; apply a certain filter
      }
      close WORDS;
    }
  }
  return (\@words, $f);
}


sub word_generate {
  my $self = shift;
  print STDOUT "Generating words.\n";
  my $amt = int(rand(5)+3); # from 3-8 words
  if(int(rand(15)) == 10 && $usefilters){
    print STDOUT "Special round! Using two different sets this time.";
    my ($word_ref, $f) = $self->wordset($amt);
    my @words = @{$word_ref};
    @words = shuffle(@words);
    @good = @words[0 .. ($amt-1)]; # get the first <x> words
    @words = $self->wordset($amt);
    @words = shuffle(@words);
    @bad = @words[0 .. ($amt-1)];
    for my $bd (@bad){
      @good = grep {$_ ne $bd} @good;
    }
    db_round_init($f, \@good, \@bad);
  } else {
    my ($word_ref, $f) = $self->wordset($amt * 2);
    my @words = shuffle(@{$word_ref});
    @good = @words[0 .. ($amt - 1)];
    @bad = @words[$amt .. (($amt * 2) - 1)];
    db_round_init($f, \@good, \@bad);
  }
}

1;
