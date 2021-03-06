use strict;
use warnings;

use Test::More 'no_plan';
use Data::Dumper;

BEGIN { use_ok("Recs::Executor"); }

use Recs::Record;

{
   my $rec = Recs::Record->new("a" => "b", "c" => "d");
   my $executor = Recs::Executor->new('{{a}}');

   ok($executor, "Executor initialized");
   is($executor->execute_code($rec), "b", "Test special lookup");
   is($executor->line_count(), 1, "Test line count");

   my $executor2 = Recs::Executor->new('{{a}} = 3 . $line');
   is($executor2->execute_code($rec), "31", "test special assign return");
   is($rec->{'a'}, "31", "test special assign");

   my $executor3 = Recs::Executor->new('$r->{foo} = "bar"');
   is($executor3->execute_code($rec), "bar", "test \$r assign return");
   is($rec->{'foo'}, "bar", "test \$r assign");

   my $rec2 = Recs::Record->new('0' => "zero");
   my $executor4 = Recs::Executor->new('{{0}}');
   is($executor4->execute_code($rec2), "zero", "test number only in special lookup");
}

use Recs::Test::OperationHelper;

my $output = <<OUTPUT;
{"foo":1,"zap":"blah1","fn":"tests/files/testFile2"}
{"foo":2,"zap":"blah2","fn":"tests/files/testFile2"}
{"foo":3,"zap":"blah3","fn":"tests/files/testFile2"}
{"value":"10.0.0.101","foo":"bar","element":"address","fn":"tests/files/testFile3"}
{"value":"10.0.1.101","foo":"bar3","element":"address","fn":"tests/files/testFile3"}
{"value":"10.0.0.102","foo":"bar3","element":"address2","fn":"tests/files/testFile3"}
{"value":"10.0.0.103","foo":"bar","element":"address2","fn":"tests/files/testFile3"}
{"value":"10.0.1.103","foo":"bar","element":"address2","fn":"tests/files/testFile3"}
OUTPUT

# Probably shouldn't use xform here, but I need a full context to test
# $filename substition
use Recs::Operation::xform;
Recs::Test::OperationHelper->do_match(
  'xform',
  ['{{fn}} = $filename', 'tests/files/testFile2', 'tests/files/testFile3'],
  '',
  $output
);
