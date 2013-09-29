package kossy_test::Web;

use strict;
use warnings;
use utf8;
use Kossy;
use DBIx::Sunny;
use DBD::mysql;
use Teng;
use Teng::Schema::Loader;
use Data::Dumper;

my $dsn = "dbi:mysql:database=kossy_test;host=localhost";
my $user = "kossy";
my $password = "kossy_test";
my $table_name = "test";


filter 'set_title' => sub {
    my $app = shift;
    sub {
        my ( $self, $c )  = @_;
        $c->stash->{site_name} = __PACKAGE__;
        $app->($self,$c);
    }
};

get '/' => [qw/set_title/] => sub {
    my ( $self, $c )  = @_;
    my $query = $c->req->param('q');

    my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    my $teng = Teng::Schema::Loader->load(
      'dbh'       => $dbh,
      'namespace' => 'KossyTest::DB',
    );

    if ($query){
        my $iter = $teng->search('test', [ 'msg', {'like' => ('%' . $query .'%') }  ], +{ order_by => 'id desc' });
        #print Dumper($iter);
        #my $count = $teng->do($like);
        #my $count = $teng->count('test', '*', {like => ('%' . $query .'%')});
        #print Dumper($count);
        $c->render('index.tx',
            { status => 'alert-info',
            message => "何かToDoを入力してください" ,
            results => $iter,
            query => $query}
        );
    } else{
        my $iter = $teng->search('test', {}, +{ order_by => 'id desc'});
        $c->render('index.tx', { status => 'alert-info', message => "何かToDoを入力してください", results => $iter });
    }
};

# create
post '/' => sub {
    my ( $self, $c )  = @_;
    # validation
    my $result = $c->req->validator([
        'msg' => {
            rule => [
                ['NOT_NULL', 'empty body'],
            ],
        },
    ]);

    my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    my $teng = Teng::Schema::Loader->load(
        'dbh'       => $dbh,
        'namespace' => 'KossyTest::DB',
    );

    # error check
    if ( $result->has_error ){
        my $iter = $teng->search('test', {}, +{ order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-error", message => "ToDoが入力されていません", results => $iter } );
    } else{
        my $insert_result = $teng->insert('test' => {
            'msg' => $result->valid('msg')
        });
        my $iter = $teng->search('test', {}, +{ order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-success", message => "ToDoを保存しました", results => $iter });
    }
    #my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    #my $teng = Teng::Schema::Loader->load(
    #    'dbh' => $dbh,
    #    'namespace' => 'MyApp::DB',
    #);
};

# edit
get '/edit'=> sub {
 my ( $self, $c )  = @_;
    # validation
    my $result = $c->req->validator([
        'id' => {
            rule => [
                ['UINT','idが不正な値です'],
            ],
        },
    ]);

    my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    my $teng = Teng::Schema::Loader->load(
        'dbh'       => $dbh,
        'namespace' => 'KossyTest::DB',
    );

    # error check
    if ( $result->has_error ){
        my $iter = $teng->search($table_name, {}, +{ order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-error", message => "入力値が不正です", results => $iter } );
    } else{
        my $row = $teng->single($table_name, {'id' => $result->valid('id')});
        $c->render('edit.tx', { row => $row } );
    }
};

# put(編集後の確定)
post '/put'=> sub {
 my ( $self, $c )  = @_;
    # validation
    my $result = $c->req->validator([
        'id' => {
            rule => [
                ['UINT','idが不正な値です'],
            ],
        },
        'msg' => {
            rule => [
                ['NOT_NULL', 'empty body'],
            ],
        },
    ]);

    my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    my $teng = Teng::Schema::Loader->load(
        'dbh'       => $dbh,
        'namespace' => 'KossyTest::DB',
    );

    # error check
    if ( $result->has_error ){
        my $row = $teng->single($table_name, {'id' => $result->valid('id')});
        my $iter = $teng->search($table_name, {}, +{ order_by => 'id desc'});
        $c->render('edit.tx', { status => "alert-error", message => "入力値が不正です", row => $row } );
    } else{
        my $row = $teng->single($table_name, {'id' => $result->valid('id')});
        my $count = $teng->update($table_name, {'msg' => $result->valid('msg') }, { 'id' => $row->id });
        my $iter = $teng->search($table_name, {}, +{ order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-success", message => "ToDo内容を変更しました" , results => $iter, row => $row } );
    }
};


# delete
post '/delete' => sub {
    my ( $self, $c )  = @_;
    # validation
    my $result = $c->req->validator([
        'id' => {
            rule => [
                ['UINT','idが不正な値です'],
            ],
        },
    ]);

    my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    my $teng = Teng::Schema::Loader->load(
        'dbh'       => $dbh,
        'namespace' => 'KossyTest::DB',
    );

    # error check
    if ( $result->has_error ){
        my $iter = $teng->search('test', {}, +{limit => 10, order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-error", message => "入力値が不正です", results => $iter } );
    } else{
        my $count = $teng->delete($table_name => {'id' => $result->valid('id')});
        my $iter = $teng->search('test', {}, +{limit => 10, order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-success", message => "ToDoを削除しました" , results => $iter } );
    }
};



#get '/json' => sub {
#    my ( $self, $c )  = @_;
#    my $result = $c->req->validator([
#        'q' => {
#            default => 'Hello',
#            rule => [
#                [['CHOICE',qw/Hello Bye/],'Hello or Bye']
#            ],
#        }
#    ]);
#    $c->render_json({ greeting => $result->valid->get('q') });
#};

1;

