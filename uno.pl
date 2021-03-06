#!/usr/bin/perl

# Three Stone Solutions (c)
# Uno IRC bot. v1.0
#
# Usage: perl bot.pl IRC_ADDR PORT NICK
# Default is efnet, 6667, and TSS_Uno
# 
# To-do:
#	. Track players who change their nickname.
#	. Get more alcohol.

use strict;
use warnings;
use IO::Socket::INET;

my @cards = qw(W W W W WD4 WD4 WD4 WD4 R0 R0 R1 R1 R2 R2 R3 R3 R4 R4 R5 R5
R6 R6 R7 R7 R8 R8 R9 R9 RD2 RD2 RR RR B0 B0 B1 B1 B2 B2 B3 B3 B4 B4 B5 B5 B6
B6 B7 B7 B8 B8 B9 B9 BD2 BD2 BR BR Y0 Y0 Y1 Y1 Y2 Y2 Y3 Y3 Y4 Y4 Y5 Y5 Y6 Y6
Y7 Y7 Y8 Y8 Y9 Y9 YD2 YD2 YR YR G0 G0 G1 G1 G2 G2 G3 G3 G4 G4 G5 G5 G6 G6 G7
G7 G8 G8 G9 G9 GD2 GD2 GR GR);

my ($chan, $drew, $owner, $top_card, $won, $x, $y, $z, @player, %hands);
my $t = 0;
$x = scalar(@cards)-1; # How many cards are in the deck?

$| = 1; # Keep my pipe hot baby!

my $host = shift || "irc.oftc.net"; # Default network.
my $port = shift || 6667; # Default irc port.
my $nick = shift || "nueno"; # Default name.

my $irc = IO::Socket::INET -> new(
  PeerAddr => $host,
  PeerPort => $port,
  Proto    => 'tcp' # TCP by default, but let's stress it.
) or die "Error creating the socket: $!\n";

print $irc "nick :$nick\n";
print $irc "user $nick 8 * :$nick\n";

while(<$irc>){
  chomp;
  if(/PING :(.*)/i){
    print $irc "PONG :$1\n";
  }
  elsif(/:(.+)!.+PRIVMSG.+:.*VERSION.*/i){
    print $irc "privmsg $1 :VERSION TTS_Uno v1.0\n";
  }
  elsif(/:.*PRIVMSG.*:!chan (.*)/i){
  	print $irc "join $1\n";
  }
  elsif(/:(.*)!.*PRIVMSG (#.*) :!start/i){
    $owner = $1;
    game_started($2);
  }
  elsif(/^:(.*)!.* PRIVMSG.* :!h\s*/ || /^:(.*)!.* PRIVMSG.* :!help\s*/i){
    help($1);
  }
  else{
    print "$_\n"; # What is our server saying?
  }
}

sub draw{
  splice(@cards, rand($x--), 1) . " "; # You mean i can return values this way?
}

sub game_started{
  $chan = shift;
  print $irc "privmsg $chan :New game started: type !join to join. You have 30 seconds until joining is over.\n";
  while(!$@){ # While our alarm didnt go off.
    eval{
      local $SIG{ALRM} = sub{ die "haxs\n" };
      alarm(30) if(!%hands);
      chomp($a=<$irc>); # Oh man, how is $a there without being declared? ;)
      if($a =~ /^:(.*)!.+PRIVMSG.*:!join/){ # There he goes again with his magic variable.
        print "$1 joined the game!\n";
        $hands{"$1"} = join '', map(draw(), 0..6) if(!exists $hands{"$1"});
        $player[$t++] = $1; # Keep track of the joining order.
      }
      else{
        print "$a\n";
      }
    };
  }
  last if(!%hands); # If nobody joined, exit the game.
	if(keys(%hands) == 1){ # If only one person joined, play the computer.
		$hands{"$nick"} = join '', map(draw(), 0..6);
		$player[$t] = $nick;
	}
  $y = $z = @player; # Lets start off with player 1.
  print $irc "privmsg $chan :Joining is over!\n";
  print $irc "privmsg $chan :[ @player ] are playing in this game.\n";
  $top_card = draw(); # Get the first card.
  start_card(); # Make sure the $top_card not a WD4.
  print $irc "privmsg $chan :Turn: $player[$y%$z] Card: $top_card\n";
  for(@player){ # Show all the players their hands.
    print $irc "notice $_ :Your hand: $hands{$_}\n";
  }
  while(<$irc>){ # Read from the socket.
    chomp;
    last if $won;
    # Set this on a timer for the user to play by!
    if(!keys(%hands)){
      print $irc "privmsg $chan :Everyone quit! Game over man, GAME OVER!\n";
      last;
    }
    elsif(/^:$owner!.+PRIVMSG $chan :!stop/i){
      print $irc "privmsg $chan :Game has been stopped.\n";
      last;
    }
    elsif(/PING :(.*)/i){
      print $irc "PONG :$1\n";
    }
#    elsif(/^:(.*)!.* NICK :(.*)\s*/i){ # If the player changes their nickname.
#    	my ($n, $i) = ($1, $2);
#    	if($hands{$n}){
#    	  $hands{$i} = "$hands{$n}";
#    	  delete $hands{$n};
#    	  for my $m (0..@player-1){
#    	    $player[$m] = "$i" if($player[$m] =~ /^$n$/i);
#          $owner = "$i" if($owner =~ /^$n$/i);
#          print "$m :: $player[$m] :: $hands{$i} :: $owner\n";
#        }
#    	}
#    }
    elsif(/^:(.*)!.* PART $chan\s*/i){
      if($hands{$1}){
        print $irc "privmsg $chan :$1 has been removed from the game.\n";
        quit_game($1);
      }
    }
    elsif(/^:(.*)!.*QUIT :.*/i){
      if($hands{$1}){
      	print $irc "privmsg $chan :$1 quit and has been removed from the game.\n";
      	quit_game($1);
      }
    }
    elsif(/^:(.*)!.* PRIVMSG $chan :!turn\s*/i || /^:(.*)!.* PRIVMSG $chan :!t\s*/i){
      print $irc "privmsg $chan :Turn: $player[$y%$z] Card: $top_card\n" if($hands{$1});
    }
    elsif(/^:(.*)!.* PRIVMSG $chan :!quit\s*/i || /^:(.*)!.* PRIVMSG $chan :!q\s*/i){
      if($hands{$1}){
        print $irc "privmsg $chan :$1 has quit.\n";
        quit_game($1);
      }
    }
    elsif(/^:(.*)!.* PRIVMSG $chan :!l\s*/i || /^:(.*)!.* PRIVMSG $chan :!list\s*/i){
      print $irc "notice $1 :$hands{$1}\n" if($hands{$1});
    }
    elsif((/^:(.*)!.* PRIVMSG $chan :!d\s*/i || /^:(.*)!.* PRIVMSG $chan :!draw\s*/i) && !$drew){ # Need a card?
      if($1 eq $player[$y%$z]){
        my $u = draw();
        $hands{$player[$y%$z]} .= $u;
        $drew++;
        print $irc "notice $player[$y%$z] :You drew a $u!\n";
      }
    }
    elsif((/^:(.*)!.* PRIVMSG $chan :!s\s*/i || /^:(.*)!.* PRIVMSG $chan :!skip\s*/ || /^:(.*)!.* PRIVMSG $chan :!pass\s*/i || /^:(.*)!.* PRIVMSG $chan :!p\s*$/) && $drew){
      if($1 eq $player[$y%$z]){
      	print $irc "privmsg $chan :$player[$y%$z] passes.\n";
        $y++;
        $drew ^= $drew;
        print $irc "privmsg $chan :Turn: $player[$y%$z] Card: $top_card\n";
      }
    }
    elsif(/^:(.*)!.* PRIVMSG $chan :!c\s*/i || /^:(.*)!.* PRIVMSG $chan :!count\s*/i){ # Works
      if($hands{$1}){
        for(keys(%hands)){
          print $irc "notice $1 :$_ : ", scalar(my @tmp=split / /, $hands{$_}), "\n";
        }
      }
    }
    elsif(/^:(.*)!.* PRIVMSG $chan :!h\s*/ || /^:(.*)!.* PRIVMSG $chan :!help\s*/i){
      help($1);
    }
    elsif(/^:(.*)!.* PRIVMSG $chan :!play .*/i || /^:(.*)!.* PRIVMSG $chan :!p .*/i){
      if($1 eq $player[$y%$z]){
        play($_);
        print $irc "privmsg $chan :Turn: $player[$y%$z] Card: $top_card\n" if(!$won);
      }
    }
    else{
    	print "$_\n";
    }
  }
  $chan ^= $chan;
  $won ^= $won;
  $top_card ^= $top_card;
  undef %hands;
  undef @player;
  undef $@;
}

sub help{ # PLAYER
  print $irc "notice $_[0] :!h : !help - This help list.\n";
  print $irc "notice $_[0] :!p  card : !play card - Play a card. W and WD4 are played as: W/WD4 r/b/g/y\n";
  print $irc "notice $_[0] :!d : !draw - Draw a card.\n";
  print $irc "notice $_[0] :!start - Start a new game.\n";
  print $irc "notice $_[0] :!s : !skip : !p : !pass - Skip yourself. (You must draw first.)\n";
  print $irc "notice $_[0] :!c : !count - List the amount of cards each player has left.\n";
  print $irc "notice $_[0] :!l : !list - List your cards.\n";
  print $irc "notice $_[0] :!q : !quit - Quit the game.\n";
  print $irc "notice $_[0] :!t : !turn - Display who's turn it is.\n";
}

sub play{
	$_ = shift;
  if(/!play\s+(.*)\s+$/i || /!p\s+(.*)\s+$/i){
    my $r = $1;
    if($r =~ /^wd4 [r|g|b|y]$/ || $r =~ /^w [r|g|b|y]$/i && $hands{$player[$y%$z]} =~ /w/i){
      push(@cards, $top_card) if($top_card !~ /.\*/);
      if($r =~ /wd4 (y|r|b|g).*/i){
        $top_card = uc("$1*");
        my $b = join '', map(draw(), 0..3);
        $hands{$player[($y+1)%$z]} .= $b;
        print $irc "notice " . $player[($y+1)%$z] . " :You drew $b\n";
        print $irc "privmsg $chan :" . $player[($y+1)%$z] . " draws four and is skipped.\n";
      }
      elsif($r =~ /w (y|r|b|g).*/i){
        $top_card = uc("$1*");
      }
      $r =~ s/(w|wd4) [y|r|b|g].*/$1/i; # w or wd4 with the color.
      $hands{$player[$y%$z]} =~ s/^(.*)$r(.*)$/$1$2/i;
      $hands{$player[$y%$z]} =~ s/\s{2}/ /g;
      $hands{$player[$y%$z]} =~ s/^\s(.*)$/$1/;
      print $irc "privmsg $chan :$player[$y%$z] has uno!\n" if($hands{$player[$y%$z]} =~ /^.{1,3}$/i);
      if($player[$y%$z] eq ''){
        $won = $player[$y%$z];
        print $irc "privmsg $chan :$player[$y%$z] won!\n";
      }
      $y += ($r =~ /wd4/i?2:1);
      $x++; # Change the deck count.
      $drew ^= $drew; # Make sure the next person to play can draw.
    }
    elsif(($r =~ /.d2/i && $hands{$player[$y%$z]} =~ /$r/i) && ($top_card =~ /.d2/i || uc substr($r, 0, 1) eq uc substr($top_card, 0, 1))){
      played($r, $player[$y%$z]);
      my $d = join '', map(draw(), 0..1);
      $hands{$player[$y%$z]} .= $d;
      print $irc "notice $player[$y%$z] :You drew: $d\n";
      print $irc "privmsg $chan :$player[$y%$z] draws two and is skipped.\n";
      $y++;
    }
    elsif(($r =~ /.r/i && $hands{$player[$y%$z]}) && ($top_card =~ /.r/i || (uc substr($r, 0, 1) eq uc substr($top_card, 0, 1)))){
      played($r, $player[$y%$z]);
      @player = reverse(@player);
      $y++ if($y%$z == $z-1 && @player != 2);
    }
    elsif($r =~ /.s/i && $hands{$player[$y%$z]} =~ /$r/i){
      if(((uc substr($r, 0, 1) eq uc substr($top_card, 0, 1)) || $top_card =~ /.s/i)){
        played($r, $player[$y%$z]);
        print $irc "privmsg $chan :$player[$y%$z] is skipped.\n";
        $y++;
      }
    }
    elsif($r !~ /w/i && ((uc substr($r, 0, 1) eq uc substr($top_card, 0, 1)) || (uc substr($r, 1, 1) eq uc substr($top_card, 1, 1)) || $top_card =~ /w/i) && $hands{$player[$y%$z]} =~ /$r/i){
      played($r, $player[$y%$z]);
    }
    else{
      print $irc "notice $player[$y%$z] :You cannot play that card or you don't have it.\n";
    }
  }
}

sub played{
  push(@cards, $top_card) unless ($top_card =~ /.\*/);
  $top_card = uc($_[0]);
  if($_[1]){
    $hands{$player[$y%$z]} =~ s/^(.*)$_[0](.*)$/$1$2/i;
    $hands{$player[$y%$z]} =~ s/\s{2}/ /g;
    $hands{$player[$y%$z]} =~ s/^\s*(.*)\s*$/$1/;
  }
  $x++; # Change the deck count.
  if($_[1] && $hands{$player[$y%$z]} eq ''){
  	$won = $player[$y%$z];
  	print $irc "privmsg $chan :$player[$y%$z] won!\n";
  }
  print $irc "notice $_[1] :$hands{$_[1]}\n";
  $y++ if($_[1]); # Change the player index. Don't change it for start_card though.
  $drew ^= $drew; # Make sure the next person to play can draw.
  print $irc "privmsg $chan :$_[1] has uno!\n" if($_[1] && $hands{$_[1]} =~ /^.{1,3}$/i);
}

sub quit_game{ # $player quits the game.
  my $p = shift;
  if($hands{$p}){
    my $n = 0;
    for(split(/\s+/, $hands{$p})){ # Put the players hand back into the deck.
      push(@cards, uc($_));
      $x++; # Increment the deck count.
    }
    for(@player){
      splice(@player, $n, 1) if(/$p/);
      $n++;
    }
    delete($hands{$p});
    $z--;
  }
}

sub start_card{ # The first card cannot be a WD4, if so redraw the top card. Else if it's a skip or draw two play it.
  while($top_card =~ /wd4/i){
    played(draw());
  }
  if($top_card =~ /.s/i){
    print $irc "privmsg $chan :$player[$y%$z] skipped.\n";
    $y++;
  }
  elsif($top_card =~ /.d2/i){
    my $d = join '', map(draw(), 0..1);
    $hands{$player[$y%$z]} .= $d;
    print $irc "notice $player[$y%$z] :You drew: $d\n";
    print $irc "privmsg $chan :$player[$y%$z] skipped.\n";
    $y++;
  }
  elsif($top_card =~ /.r/i){
    @player = reverse(@player);
    $y++ if((($y%$z) == ($z-1)) && (@player != 2));
  }
}

sub think{
	$hands{"$nick"};
}

