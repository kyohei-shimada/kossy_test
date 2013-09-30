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
use Text::MeCab;
use Encode 'decode';
use String::Trigram;

my $dsn = "dbi:mysql:database=kossy_test;host=localhost";
my $user = "kossy";
my $password = "kossy_test";
my $table_name = "test";

# DB用のtengオブジェクトの取得
sub teng {
    my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    my $teng = Teng::Schema::Loader->load(
      'dbh'       => $dbh,
      'namespace' => 'KossyTest::DB',
    );

    $teng;
}

# 指定した文字列がNGワードに含まれているか？
# args : ($msg)
#    $msg : 比較する文1
# return : 含まれているなら1, 含まれていなければ0
sub is_ng {
    my $self = shift;
    my $msg = shift;

    my $ng_words = ['等', 'など', '的', 'とか', '多分', 'たぶん', 'それなり', '色々', 'いろいろ', 'さまざま', '様々'];
    my $ng_phrases = +["何か", "なんか", "なにか"];

    my $is_ng = 0;
    my $m = Text::MeCab->new();
    my $n = $m->parse($msg);
    while ($n->surface) {
        my $word = decode('UTF-8', $n->surface);
        $n = $n->next;
        foreach my $ng_word (@$ng_words) {
            if ($ng_word =~ /^$word$/){
                $is_ng = 1;
                last;
            }
        }
    }

    # (NG文節のチェック)
    foreach my $ng_phrase (@$ng_phrases) {
        if ($msg =~ /$ng_phrase/){
           $is_ng = 1;
           last;
        }
    }

    $is_ng;
}

# 2つの文の類似度をtrigramで計算する
# args : ($text1, $text2)
#    $text1 : 比較する文1
#    $text2 : 比較する文2
# return : 類似度
sub trigram {
    my $self = shift;
    my $text1 = shift;
    my $text2 = shift;

    String::Trigram::compare($text1, $text2);
}

# 指定した文に似ているToDoの配列を取得する
# args : ($teng, $compared, $compare_data, $th)
#    $teng : $tengオブジェクト
#    $compared : 比較される文
#    $th : しきい値(0〜1.0)[完全一致が1.0]
#    $id : 例外として取り除くid(自分自身を除きたい場合に使用．使用しない場合0)
sub get_relations {
    my $self = shift;
    my $teng = shift;
    my $compared = shift;
    my $th = shift;
    my $id = shift;

    my $itr = $teng->search('test', {}, +{ order_by => 'id desc' });
    my $results;
    while( my $row = $itr->next ) {
        my $text = $row->msg;
        my $sim = String::Trigram::compare($text, $compared);
        if($sim >= $th){
            #自分自身は除く
            if($row->id != $id){
                push(@$results, $row);
                print Dumper ($sim . " , " . $row->id);
            }
        }
    }

    $results;
}

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

    my $teng = $self->teng();

    if ($query){
        my $iter = $teng->search('test', [ 'msg', {'like' => ('%' . $query .'%') }  ], +{ order_by => 'id desc' });
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

    my $teng = $self->teng();
    # 形態素解析(NGワードのチェック)
    my $is_ng = $self->is_ng($result->valid('msg'));
    my $similers = $self->get_relations($teng, $result->valid('msg'), 0.1, 0);
    my $sim;

    #my $sub_msgs = "";
    #foreach my $sim (@$similers) {
    #    $sub_msgs = $sub_msg . ($sim->id . '「' . $sim->msg . "」<br/>");
    #}

    #print Dumper "=====";
    #print Dumper $sub_msg;

    # error check
    if ( $is_ng ){
        my $iter = $teng->search('test', {}, +{ order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-error", message => "ToDoに曖昧な表現が含まれています．より具体的にToDoを記述してください", results => $iter } );
    } elsif ( $result->has_error ){
        my $iter = $teng->search('test', {}, +{ order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-error", message => "ToDoが入力されていません", results => $iter } );
    } else{
        my $insert_result = $teng->insert('test' => {
            'msg' => $result->valid('msg')
        });
        my $iter = $teng->search('test', {}, +{ order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-success", message => "ToDo : 「" . $result->valid('msg') ."」を作成しました", results => $iter, similers => $similers, sim => $sim});
    }
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

    my $teng = $self->teng();

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

    my $teng = $self->teng();
    my $is_ng = $self->is_ng($result->valid('msg'));
    my $similers;
    my $sim;

    # error check
    if ( $is_ng ){
        my $iter = $teng->search('test', {}, +{ order_by => 'id desc'});
        $c->render('edit.tx', { status => "alert-error", message => "ToDoに曖昧な表現が含まれています．より具体的にToDoを記述してください", results => $iter } );
    } elsif ( $result->has_error ){
        my $row = $teng->single($table_name, {'id' => $result->valid('id')});
        my $iter = $teng->search($table_name, {}, +{ order_by => 'id desc'});
        $c->render('edit.tx', { status => "alert-error", message => "入力値が不正です", row => $row } );
    } else{
        my $row = $teng->single($table_name, {'id' => $result->valid('id')});
        my $count = $teng->update($table_name, {'msg' => $result->valid('msg') }, { 'id' => $row->id });
        my $iter = $teng->search($table_name, {}, +{ order_by => 'id desc'});

        $similers = $self->get_relations($teng, $result->valid('msg'), 0.1, $row->id);

        $c->render('index.tx', { status => "alert-success", message => "ToDo : 「" . $row->msg . "」を「" . $result->valid('msg') . "」に変更しました" , results => $iter, row => $row, similers => $similers, sim => $sim } );
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

    my $teng = $self->teng();

    # error check
    if ( $result->has_error ){
        my $iter = $teng->search('test', {}, +{order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-error", message => "入力値が不正です", results => $iter } );
    } else{
        my $row = $teng->single($table_name, {'id' => $result->valid('id')});
        #print Dumper $row->msg;
        my $count = $teng->delete($table_name => {'id' => $result->valid('id')});
        my $iter = $teng->search('test', {}, +{order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-success", message => "ToDo : 「" . $row->msg . "」を削除しました" , results => $iter } );
    }
};

1;

