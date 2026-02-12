#!/bin/bash

# ========================================
# 統合テスト実行チェックリスト
# ========================================

echo "========================================="
echo "  統合テスト実行チェックリスト"
echo "========================================="
echo ""
echo "このスクリプトは、15項目の統合テストをガイドします。"
echo "各テストケースを実行し、結果を記録してください。"
echo ""

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 結果記録
RESULTS_FILE="integration_test_results_$(date +%Y%m%d_%H%M%S).txt"

echo "結果ファイル: $RESULTS_FILE"
echo ""

# ヘルパー関数
test_item() {
    local category=$1
    local number=$2
    local title=$3
    local description=$4

    echo "" | tee -a "$RESULTS_FILE"
    echo "=========================================" | tee -a "$RESULTS_FILE"
    echo -e "${BLUE}[$category] Test $number: $title${NC}" | tee -a "$RESULTS_FILE"
    echo "=========================================" | tee -a "$RESULTS_FILE"
    echo "$description" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"

    read -p "このテストを実行しましたか？ (y/n/skip): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "テスト結果は成功でしたか？ (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✓ PASS${NC}" | tee -a "$RESULTS_FILE"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC}" | tee -a "$RESULTS_FILE"
            read -p "エラー詳細を入力してください: " error_detail
            echo "  エラー: $error_detail" | tee -a "$RESULTS_FILE"
            return 1
        fi
    elif [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}⊘ SKIP${NC}" | tee -a "$RESULTS_FILE"
        return 2
    else
        echo -e "${YELLOW}⊘ NOT EXECUTED${NC}" | tee -a "$RESULTS_FILE"
        return 2
    fi
}

# ========================================
# 前提条件チェック
# ========================================
echo "=========================================" | tee -a "$RESULTS_FILE"
echo "前提条件チェック" | tee -a "$RESULTS_FILE"
echo "=========================================" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

echo "1. バックエンドが起動していますか？ (http://localhost:8000)" | tee -a "$RESULTS_FILE"
read -p "   (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}エラー: バックエンドを先に起動してください${NC}"
    echo "  実行: ./run_backend.sh"
    exit 1
fi

echo "2. フロントエンドが起動していますか？ (http://localhost:5000)" | tee -a "$RESULTS_FILE"
read -p "   (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}エラー: フロントエンドを先に起動してください${NC}"
    echo "  実行: ./run_frontend.sh"
    exit 1
fi

echo "" | tee -a "$RESULTS_FILE"
echo -e "${GREEN}✓ 前提条件クリア${NC}" | tee -a "$RESULTS_FILE"

# ========================================
# CRITICAL TESTS (必須)
# ========================================

test_item "CRITICAL" "1" "エンドツーエンド推奨生成" \
"手順:
  1. ブラウザで http://localhost:5000 を開く
  2. ホーム画面で3枚のカードが表示されるか確認
  3. カード1: クローゼットベース（agent_type確認）
  4. カード2: クローゼットベース（agent_type確認）
  5. カード3: 楽天商品ベース（source='external'確認）
  6. 天気・TPO情報が表示されるか確認

期待結果:
  - 3枚のカードが表示される
  - 各カードにスコア・推奨理由が表示される
  - 天気・TPO情報が正しく表示される"

test_item "CRITICAL" "2" "Tier制限動作" \
"手順:
  1. ホーム画面で3枚のカードを全て左スワイプ（拒否）
  2. 「別のコーデを見ますか？」プロンプトが表示される
  3. 「新しいコーデを生成」ボタンを押下（1回目の再生成）
  4. 新しい3枚のカードが表示される
  5. 再度全て左スワイプ（拒否）
  6. 「新しいコーデを生成」ボタンを押下（2回目の再生成）

期待結果:
  - 2回目の再生成で429エラー
  - オレンジ色の警告UIが表示される
  - 「本日の生成回数上限に達しました」メッセージ表示
  - 「Free tierは1日1回の生成制限があります。明日0時にリセットされます。」説明表示
  - 「Premium にアップグレード」ボタン（オレンジ色）表示"

test_item "CRITICAL" "3" "キャッシュ効果" \
"手順:
  1. ブラウザをリロード（F5）
  2. カードが即座に表示されるか確認
  3. バックエンドログで「Using cached recommendation」確認

期待結果:
  - 500ms以内にカード表示
  - エージェント実行なし（ログ確認）
  - キャッシュから読み込み"

test_item "CRITICAL" "4" "スワイプアクション記録" \
"手順:
  1. カード1を右スワイプ（承認）
  2. 緑色の「承認」インジケーターが表示される
  3. 次のカードに自動移動
  4. Firebase Consoleで以下を確認:
     - users/{user_id}/swipe_history にドキュメント追加
     - users/{user_id}/preference_profile が更新
     - style_scores, color_preferences, total_swipes 更新

期待結果:
  - スワイプが記録される
  - preference_profile が更新される
  - approve_rate が計算される"

test_item "CRITICAL" "5" "Firebase認証統合" \
"手順:
  1. ログアウト状態でホーム画面アクセス
  2. バックエンドログで「demo_user」として動作確認
  3. Firebase Authenticationでログイン
  4. バックエンドログでBearer トークン確認
  5. 正規ユーザーIDで動作確認

期待結果:
  - 未認証: demo_user として動作
  - 認証済み: 実際のユーザーIDで動作
  - Authorization Headerが正しく送信される"

# ========================================
# HIGH PRIORITY TESTS (推奨)
# ========================================

test_item "HIGH" "6" "マルチエージェント並列実行" \
"手順:
  1. バックエンドログを確認
  2. 「Generating outfits with 4 agents in parallel」メッセージ確認
  3. 各エージェント（Casual, Formal, Balanced, Unique）の起動ログ確認
  4. asyncio.gather() による並列実行確認

期待結果:
  - 4エージェントが並列実行される
  - 実行時間が短縮される（シーケンシャルより速い）"

test_item "HIGH" "7" "スコアリングアルゴリズム" \
"手順:
  1. カードのスコアを確認
  2. バックエンドログでスコア計算詳細を確認
  3. エージェントのbase_scoreが信頼されているか確認
  4. TPOボーナス（±10%）、嗜好ボーナス（±5%）が適用されているか確認

期待結果:
  - 最終スコア = base_score + TPO_bonus + preference_bonus
  - 0-100の範囲内"

test_item "HIGH" "8" "楽天API統合" \
"手順:
  1. カード3（外部商品）を確認
  2. 楽天商品の画像、価格、ショップ名が表示される
  3. バックエンドログで楽天API呼び出し確認
  4. ジャンルIDマッピングが正しいか確認

期待結果:
  - 楽天商品が正しく表示される
  - 商品URLタップで楽天サイトへ遷移"

test_item "HIGH" "9" "気温範囲推定" \
"手順:
  1. バックエンドログで気温範囲推定ログ確認
  2. 各アイテムにtemperature_rangeが付与されているか確認
  3. カテゴリ・季節・素材に基づく推定が正しいか確認

期待結果:
  - クローゼットアイテムに温度範囲が自動付与
  - 天気に適したアイテムがフィルタリングされる"

test_item "HIGH" "10" "スワイプUI" \
"手順:
  1. カードをドラッグして左右にスワイプ
  2. スワイプ中のインジケーター（緑/赤）表示確認
  3. スワイプ完了後のアニメーション確認
  4. 複数カードのスタック表示確認

期待結果:
  - スムーズなスワイプアニメーション
  - インジケーターが正しく表示される
  - カードスタックが正しく表示される"

# ========================================
# MEDIUM PRIORITY TESTS (オプション)
# ========================================

test_item "MEDIUM" "11" "オンボーディング簡素化" \
"手順:
  1. 新規ユーザーとしてアプリ起動
  2. オンボーディング画面を確認
  3. 性別、年齢範囲、職業のみ入力
  4. スタイル嗜好・体型・ライフスタイルが削除されているか確認

期待結果:
  - 3フィールドのみ入力
  - オンボーディングが簡潔"

test_item "MEDIUM" "12" "エラーUI" \
"手順:
  1. Tier制限エラーUI確認（Test 2で確認済み）
  2. 一般エラーUI確認（バックエンド停止してアクセス）
  3. ローディングUI確認（初回アクセス時）

期待結果:
  - 各エラーに適したUIが表示される
  - エラーメッセージが明確"

test_item "MEDIUM" "13" "再生成プロンプト" \
"手順:
  1. 3枚のカードを全て左スワイプ
  2. 「別のコーデを見ますか？」プロンプト表示確認
  3. 残り生成回数表示確認
  4. 再生成ボタンの有効/無効状態確認

期待結果:
  - プロンプトが正しく表示される
  - 残り生成回数が正確"

test_item "MEDIUM" "14" "エージェントヘルスチェック" \
"手順:
  1. http://localhost:8000/api/v1/agent/health にアクセス
  2. 4エージェントのステータス確認
  3. 各エージェントのバージョン確認

期待結果:
  - 全エージェントが「healthy」
  - バージョン情報が正しく表示される"

test_item "MEDIUM" "15" "データモデル" \
"手順:
  1. ブラウザDevToolsでNetworkタブを開く
  2. /outfit/daily のレスポンスを確認
  3. recommendations, weather, tpo, generations_remaining, can_regenerate フィールド確認
  4. 各recommendationのフィールド確認（id, agent_type, items, score, reasoning, source）

期待結果:
  - データモデルが正しく定義されている
  - すべてのフィールドが存在する"

# ========================================
# テスト結果サマリー
# ========================================
echo "" | tee -a "$RESULTS_FILE"
echo "=========================================" | tee -a "$RESULTS_FILE"
echo "テスト結果サマリー" | tee -a "$RESULTS_FILE"
echo "=========================================" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

echo -e "${GREEN}統合テストが完了しました！${NC}"
echo ""
echo "結果は $RESULTS_FILE に保存されています。"
echo ""
echo "次のステップ:"
echo "  1. FAILしたテストがあれば、エラーを修正"
echo "  2. 全テストPASSで本番デプロイ準備"
echo "  3. INTEGRATION_TEST_REPORT.md を参照"
echo ""
