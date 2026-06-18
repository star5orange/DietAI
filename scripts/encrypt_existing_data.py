"""
将数据库中已有的明文敏感数据加密，并填充盲索引。

用法: uv run python scripts/encrypt_existing_data.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import text
from shared.models.database import engine
from shared.utils.field_encryption import encrypt_field
from shared.utils.auth import _blind_index


def migrate():
    with engine.begin() as conn:
        # 1. 加密 users 表的 email/phone，填充盲索引
        result = conn.execute(
            text("SELECT id, email, phone FROM users WHERE email IS NOT NULL OR phone IS NOT NULL")
        )
        rows = result.fetchall()
        print(f"Found {len(rows)} user records to encrypt")

        for row in rows:
            user_id, email, phone = row
            updates = []
            params = {"uid": user_id}

            if email:
                encrypted_email = encrypt_field(email)
                email_hash = _blind_index(email)
                updates.append("email = :email, email_hash = :email_hash")
                params["email"] = encrypted_email
                params["email_hash"] = email_hash

            if phone:
                encrypted_phone = encrypt_field(phone)
                phone_hash = _blind_index(phone)
                updates.append("phone = :phone, phone_hash = :phone_hash")
                params["phone"] = encrypted_phone
                params["phone_hash"] = phone_hash

            if updates:
                sql = f"UPDATE users SET {', '.join(updates)} WHERE id = :uid"
                conn.execute(text(sql), params)
                print(f"  user {user_id}: email={'Y' if email else '-'} phone={'Y' if phone else '-'}")

        # 2. 加密 user_profiles 表
        result = conn.execute(
            text("SELECT id, real_name, occupation, region FROM user_profiles")
        )
        rows = result.fetchall()
        print(f"\nFound {len(rows)} profile records to encrypt")

        for row in rows:
            profile_id, real_name, occupation, region = row
            updates = []
            params = {"pid": profile_id}

            if real_name:
                updates.append("real_name = :real_name")
                params["real_name"] = encrypt_field(real_name)
            if occupation:
                updates.append("occupation = :occupation")
                params["occupation"] = encrypt_field(occupation)
            if region:
                updates.append("region = :region")
                params["region"] = encrypt_field(region)

            if updates:
                sql = f"UPDATE user_profiles SET {', '.join(updates)} WHERE id = :pid"
                conn.execute(text(sql), params)
                print(f"  profile {profile_id}: done")

        # 3. 加密 diseases 表
        result = conn.execute(
            text("SELECT id, disease_code, disease_name, notes FROM diseases")
        )
        rows = result.fetchall()
        print(f"\nFound {len(rows)} disease records to encrypt")

        for row in rows:
            did, disease_code, disease_name, notes = row
            updates = []
            params = {"did": did}

            if disease_code:
                updates.append("disease_code = :disease_code")
                params["disease_code"] = encrypt_field(disease_code)
            if disease_name:
                updates.append("disease_name = :disease_name")
                params["disease_name"] = encrypt_field(disease_name)
            if notes:
                updates.append("notes = :notes")
                params["notes"] = encrypt_field(notes)

            if updates:
                sql = f"UPDATE diseases SET {', '.join(updates)} WHERE id = :did"
                conn.execute(text(sql), params)
                print(f"  disease {did}: done")

        # 4. 加密 allergies 表
        result = conn.execute(
            text("SELECT id, allergen_name, reaction_description FROM allergies")
        )
        rows = result.fetchall()
        print(f"\nFound {len(rows)} allergy records to encrypt")

        for row in rows:
            aid, allergen_name, reaction_description = row
            updates = []
            params = {"aid": aid}

            if allergen_name:
                updates.append("allergen_name = :allergen_name")
                params["allergen_name"] = encrypt_field(allergen_name)
            if reaction_description:
                updates.append("reaction_description = :reaction_description")
                params["reaction_description"] = encrypt_field(reaction_description)

            if updates:
                sql = f"UPDATE allergies SET {', '.join(updates)} WHERE id = :aid"
                conn.execute(text(sql), params)
                print(f"  allergy {aid}: done")

        # 5. 加密 weight_records.notes
        result = conn.execute(
            text("SELECT id, notes FROM weight_records WHERE notes IS NOT NULL")
        )
        rows = result.fetchall()
        print(f"\nFound {len(rows)} weight record notes to encrypt")

        for row in rows:
            wid, notes = row
            conn.execute(
                text("UPDATE weight_records SET notes = :notes WHERE id = :wid"),
                {"wid": wid, "notes": encrypt_field(notes)},
            )
            print(f"  weight {wid}: done")

    print("\nData encryption migration done!")


if __name__ == "__main__":
    migrate()
