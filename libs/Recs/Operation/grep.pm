package Recs::Operation::grep;

use strict;

use base qw(Recs::Operation);

use Recs::Executor;

sub init {
   my $this = shift;
   my $args = shift;

   my $anti_match;
   my $context = 0;
   my $after   = 0;
   my $before  = 0;
   my $spec = {
      "-v"  => \$anti_match,
      "C=s" => \$context,
      "A=s" => \$after,
      "B=s" => \$before,
   };

   $this->parse_options($args, $spec);

   if ( ! @{$this->_get_extra_args()} ) {
      die "Missing expression\n";
   }

   $this->{'ANTI_MATCH'} = $anti_match;

   if ( $context ) {
     $after = $before = $context;
   }

   $this->{'AFTER'}  = $after;
   $this->{'BEFORE'} = $before;

   $this->{'ACCUMULATOR'} = [];

   my $expression = shift @{$this->_get_extra_args()};
   my $executor = Recs::Executor->new($expression);
   $this->{'EXECUTOR'} = $executor;
}

sub accept_record {
   my $this   = shift;
   my $record = shift;

   my $executor = $this->{'EXECUTOR'};
   my $result = $executor->execute_code($record);

   $result = not $result if ( $this->{'ANTI_MATCH'} );
   my $pushed_record = 0;

   if ( $result && ! $executor->last_error() ) {
     if ( $this->{'BEFORE'} ) {
       while(my $record = shift @{$this->{'ACCUMULATOR'}}) {
         $this->push_record($record);
       }
     }

     $this->push_record($record);
     $pushed_record = 1;
     $this->{'SEEN_RECORD'} = 1;

     if ( $this->{AFTER} > 0 ) {
       $this->{'FORCED_OUTPUT'} = $this->{'AFTER'};
     }
   }
   elsif ( $this->{'BEFORE'} > 0 ) {
     push @{$this->{'ACCUMULATOR'}}, $record;

     if ( (scalar @{$this->{'ACCUMULATOR'}}) > $this->{'BEFORE'} ) {
       shift @{$this->{'ACCUMULATOR'}};
     }
   }

   if ( $this->{'FORCED_OUTPUT'} && (! $pushed_record) )  {
     $this->push_record($record);
     $this->{'FORCED_OUTPUT'}--;
   }
}

sub stream_done {
   my $this = shift;
   $this->_set_exit_value(1) unless ( $this->{'SEEN_RECORD'} );
}

sub add_help_types {
   my $this = shift;
   $this->use_help_type('keyspecs');
   $this->use_help_type('snippet');
}

sub usage {
   return <<USAGE;
Usage: recs-grep <args> <expr> [<files>]
   <expr> is evaluated as perl on each record of input (or records from
   <files>) with \$r set to a Recs::Record object and \$line set to the current
   line number (starting at 1).  Records for which the evaluation is a perl
   true are printed back out.

Arguments:
   -v       Anti-match.  Records NOT matching <expr> will be returned
   -C NUM   Provide NUM records of context around matches, 
            equivalent to -A NUM and -B NUM
   -A NUM   Print out NUM following records after a match
   -B NUM   Print out the previous NUM records on a match

Examples:
   Filter to records with field 'name' equal to 'John'
      recs-grep '\$r->{name} eq "John"'
   Find fields without ppid = 3456
     recs-grep -v '{{ppid}} == 3456'
USAGE
}

1;
