# MOCK: モック設定モジュール - 本番リリース前に削除必須
"""
Mock Configuration Module

本番環境では絶対に使用しないこと。
全てのモックコードは `# MOCK:` でマークされています。

削除確認コマンド:
    grep -r "# MOCK:" backend/
    grep -r "from mock" backend/
    grep -r "import mock" backend/
"""
import os
import logging

# MOCK: 環境変数でモックモードを切り替え
MOCK_MODE = os.getenv("MOCK_MODE", "true").lower() == "true"  # MOCK: デフォルトtrue（開発用）

# MOCK: モックモードの警告表示
logger = logging.getLogger(__name__)

if MOCK_MODE:
    # MOCK: 起動時の警告
    logger.warning("=" * 60)
    logger.warning("⚠️  MOCK MODE ENABLED - DO NOT USE IN PRODUCTION")
    logger.warning("   Set MOCK_MODE=false for production deployment")
    logger.warning("=" * 60)


def is_mock_mode() -> bool:
    # MOCK: モードチェック関数
    """モックモードかどうかを返す"""
    return MOCK_MODE


def require_real_api() -> None:
    # MOCK: 本番環境チェック関数
    """本番環境でモックモードだった場合に例外を発生"""
    if MOCK_MODE and os.getenv("ENVIRONMENT") == "production":
        raise RuntimeError(
            "MOCK MODE is enabled in production! "
            "Set MOCK_MODE=false or remove mock code before deployment."
        )
