# auth_routes.py

from app import app, API_PREFIX, get_auth_db_connection, _resolve_table_casing, _get_column_types
from flask import request, jsonify, session, g
import bcrypt
import psycopg2
from psycopg2 import sql, extras
from datetime import date
from typing import Any, Dict, List, Optional, Tuple, Union

# Note: The 'app' object and all utility functions are imported from the main 'app.py' file.

@app.route(f'{API_PREFIX}/login', methods=['POST'])
def login_user():
    """
    Handles user login by:
    1. Checking the external 'musr' database for password validity.
    2. If valid, checking the 'mylims' database to determine user type and retrieve user details.
    """
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    # --- 1. SPECIAL ADMIN LOGIN (Hardcoded) ---
    if username == 'TIFI' and password == 'password':
        session['user_id'] = 'TIFI'
        session['user_type'] = 'admin'
        session['is_admin'] = True
        return jsonify({"success": True, "user": {"full_name": "TIFI Admin", "person_id": "TIFI"}, "user_type": "admin"}), 200

    if username == 'kasmi' and password == 'password':
        session['user_id'] = 'kasmi'
        session['user_type'] = 'superadmin'
        session['is_admin'] = True
        return jsonify({"success": True, "user": {"full_name": "Kasmi Superadmin", "person_id": "kasmi"}, "user_type": "superadmin"}), 200

    # --- 2. AUTHENTICATION (Check against the external 'musr' database) ---
    auth_conn = get_auth_db_connection()
    if not auth_conn:
        return jsonify({"error": "Authentication system unavailable. Please contact the administrator."}), 503

    password_hash = None
    try:
        with auth_conn.cursor() as cur:
            query_auth = 'SELECT pswd_hash FROM aaa.lg_fi WHERE login = %s;'
            cur.execute(query_auth, (username,))
            auth_record = cur.fetchone()
            if auth_record:
                password_hash = auth_record[0]
        auth_conn.close()
    except Exception as e:
        print(f"Authentication DB error for {username}: {e}")
        if auth_conn and not auth_conn.closed:
            auth_conn.close()
        return jsonify({"error": "An internal error occurred during authentication setup."}), 500

    if not password_hash:
        return jsonify({"error": "Invalid credentials: User not found."}), 401
    
    try:
        if not bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8')):
            return jsonify({"error": "Invalid credentials: Password mismatch."}), 401
    except ValueError as e:
        print(f"Bcrypt hash error for user {username}: {e}")
        return jsonify({"error": "Authentication failed: Corrupted or invalid password hash stored."}), 500

    # --- 3. AUTHORIZATION (Identify user type in 'mylims' database) ---
    mylims_conn = g.db_conn
    user_info = None
    user_type = None
    user_id = None

    try:
        with mylims_conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # 3.1 Try to log in as a regular lab member
            query_personal = 'SELECT person_id, full_name, mail, room, telephone, organization FROM "lims"."personal" WHERE person_id = %s OR mail = %s;'
            cur.execute(query_personal, (username, username))
            user_personal = cur.fetchone()

            if user_personal:
                user_info = user_personal
                user_type = 'personal'
                user_id = user_personal['person_id']

            # 3.2 Try to log in as a customer
            if not user_info:
                query_customers = 'SELECT customer_id, customer_name, mail, phone, address, organization FROM "lims"."customers" WHERE mail = %s;'
                cur.execute(query_customers, (username,))
                user_customer = cur.fetchone()
                if user_customer:
                    user_info = user_customer
                    user_type = 'customer'
                    user_id = str(user_customer['customer_id'])

            # 3.3 Try to log in as an external contact
            if not user_info:
                query_external_contacts = 'SELECT contact_id, full_name, mail, telephone, organization, address FROM "lims"."external_contacts" WHERE mail = %s;'
                cur.execute(query_external_contacts, (username,))
                user_external = cur.fetchone()
                if user_external:
                    user_info = user_external
                    user_type = 'external_contact'
                    user_id = user_external['contact_id']

            if not user_info:
                return jsonify({"error": "User successfully authenticated but LIMS profile not found. Contact LIMS support."}), 401

    except Exception as e:
        print(f"LIMS DB lookup error for {username}: {e}")
        return jsonify({"error": "An internal server error occurred during LIMS profile lookup."}), 500
    
    # --- 4. SESSION CREATION ---
    session['user_id'] = user_id
    session['user_type'] = user_type
    session['is_admin'] = (user_type == 'personal') 
    
    return jsonify({"success": True, "user": user_info, "user_type": user_type}), 200


@app.route(f'{API_PREFIX}/logout', methods=['POST'])
def logout_user():
    """Logs out the current user by clearing the session."""
    session.pop('user_id', None)
    session.pop('user_type', None)
    session.pop('is_admin', None)
    return jsonify({"success": True, "message": "Logged out"}), 200

@app.route(f'{API_PREFIX}/user/change-password', methods=['POST'])
def change_password():
    """Changes the user's password hash solely in the external musr.aaa.lg_fi table."""
    user_id = session.get('user_id')
    user_type = session.get('user_type')
    if not user_id:
        return jsonify({"error": "Unauthorized. Please log in."}), 401
    
    data = request.get_json()
    new_password = data.get('new_password')
    
    if not new_password or len(new_password) < 8:
        return jsonify({"error": "Password must be at least 8 characters long."}), 400

    # 2. Determine the correct 'login' value for the aaa.lg_fi table
    login_id_for_auth_db = user_id
    mylims_conn = g.db_conn
    
    try:
        with mylims_conn.cursor() as cur:
            if user_type == 'customer':
                cur.execute('SELECT mail FROM "lims"."customers" WHERE customer_id = %s;', (int(user_id),))
                mail_record = cur.fetchone()
                if mail_record and mail_record[0]:
                    login_id_for_auth_db = mail_record[0]
                else:
                    return jsonify({"error": "LIMS profile not found for password change lookup."}), 404

            elif user_type == 'external_contact':
                cur.execute('SELECT mail FROM "lims"."external_contacts" WHERE contact_id = %s;', (user_id,))
                mail_record = cur.fetchone()
                if mail_record and mail_record[0]:
                    login_id_for_auth_db = mail_record[0]
                else:
                    return jsonify({"error": "LIMS profile not found for password change lookup."}), 404
    except Exception as e:
        print(f"Error resolving login ID from LIMS DB: {e}")
        return jsonify({"error": "Failed to look up user credentials."}), 500


    # 3. Generate the new bcrypt hash
    try:
        salt = bcrypt.gensalt()
        new_hash = bcrypt.hashpw(new_password.encode('utf-8'), salt).decode('utf-8')
    except Exception:
        return jsonify({"error": "Failed to hash password internally."}), 500

    # 4. Connect to the external musr database and update the hash
    auth_conn = get_auth_db_connection()
    if not auth_conn:
        return jsonify({"error": "Authentication database unavailable for update."}), 503

    try:
        with auth_conn.cursor() as cur:
            query = 'UPDATE aaa.lg_fi SET pswd_hash = %s WHERE login = %s RETURNING login;'
            cur.execute(query, (new_hash, login_id_for_auth_db))
            updated_login = cur.fetchone()
        auth_conn.close()

        if updated_login:
            # Force user to re-login immediately
            session.pop('user_id', None)
            session.pop('user_type', None)
            session.pop('is_admin', None)
            return jsonify({"success": True, "message": "Password updated successfully. Please log in again."}), 200
        else:
            return jsonify({"error": "User login ID not found in the authentication table (aaa.lg_fi). Check user sync."}), 404
            
    except Exception as e:
        print(f"Error updating password in musr DB for {login_id_for_auth_db}: {e}")
        if auth_conn and not auth_conn.closed:
            auth_conn.close()
        return jsonify({"error": "Database error during password update."}), 500