"""Role-aware Flask interface for the REIMS course project."""
import os
import re
import secrets
from contextlib import contextmanager
from datetime import date
from decimal import Decimal
from functools import wraps
from uuid import UUID, uuid4

import pymysql
from pymysql.cursors import DictCursor
from flask import Flask, abort, flash, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.exceptions import HTTPException

app = Flask(__name__)
app.secret_key = os.getenv("REIMS_FLASK_SECRET") or secrets.token_hex(32)
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax")
if os.getenv("REIMS_COOKIE_SECURE") == "1":
    app.config["SESSION_COOKIE_SECURE"] = True

ROLE_TITLES = {
    "ADMIN": "Admin / Property Manager",
    "AGENT": "Agent",
    "OWNER": "Owner",
    "TENANT_BUYER": "Tenant / Buyer",
}


def connect_db():
    return pymysql.connect(
        host=os.getenv("REIMS_DB_HOST", "127.0.0.1"),
        port=int(os.getenv("REIMS_DB_PORT", "3306")),
        user=os.getenv("REIMS_DB_USER", "root"),
        password=os.getenv("REIMS_DB_PASSWORD", ""),
        database=os.getenv("REIMS_DB_NAME", "reims_db"),
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=False,
    )


@contextmanager
def db_cursor():
    conn = connect_db()
    try:
        with conn.cursor() as cur:
            yield conn, cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def call_procedure(cur, sql, params=()):
    cur.execute(sql, params)
    while cur.nextset():
        pass


def money(value):
    return f"{value:,.0f} VND" if value is not None else "—"


@app.template_filter("money")
def money_filter(value):
    return money(value)


def csrf_value():
    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_urlsafe(32)
    return session["csrf_token"]


@app.context_processor
def template_context():
    return {
        "current_user": getattr(g, "current_user", None),
        "role_titles": ROLE_TITLES,
        "csrf_token": csrf_value(),
    }


def has_admin_account():
    with db_cursor() as (_, cur):
        cur.execute("SELECT 1 FROM user_account WHERE actor_role='ADMIN' LIMIT 1")
        return cur.fetchone() is not None


@app.before_request
def load_user_and_check_csrf():
    csrf_token = session.get("csrf_token")
    if request.method == "POST":
        submitted = request.form.get("csrf_token", "")
        if not csrf_token or not secrets.compare_digest(csrf_token, submitted):
            abort(400, description="This form expired. Refresh the page and try again.")

    if request.endpoint in {"static", "login", "setup"}:
        return

    account_id = session.get("account_id")
    if not account_id:
        try:
            return redirect(url_for("setup" if not has_admin_account() else "login"))
        except Exception:
            return redirect(url_for("login"))

    with db_cursor() as (_, cur):
        cur.execute("""SELECT a.account_id,a.username,a.actor_role,a.person_id,a.is_active,p.full_name
                       FROM user_account a LEFT JOIN person p ON p.person_id=a.person_id
                       WHERE a.account_id=%s""", (account_id,))
        account = cur.fetchone()
    if not account or not account["is_active"]:
        session.clear()
        return redirect(url_for("login"))
    g.current_user = account


def roles_required(*roles):
    def decorate(view):
        @wraps(view)
        def wrapped(*args, **kwargs):
            if not getattr(g, "current_user", None):
                return redirect(url_for("login"))
            if g.current_user["actor_role"] not in roles:
                abort(403, description="Your account does not have permission to perform this action.")
            return view(*args, **kwargs)
        return wrapped
    return decorate


def scope_property(role, person_id, property_alias="p", lease_alias="l"):
    if role == "AGENT":
        return f"{property_alias}.agent_id=%s", [person_id]
    if role == "OWNER":
        return f"{property_alias}.owner_id=%s", [person_id]
    if role == "TENANT_BUYER":
        return f"EXISTS (SELECT 1 FROM lease own_l WHERE own_l.property_id={property_alias}.property_id AND own_l.tenant_id=%s)", [person_id]
    return "1=1", []


def valid_username(value):
    return bool(re.fullmatch(r"[A-Za-z0-9_.-]{3,80}", value))


@app.route("/setup", methods=["GET", "POST"])
def setup():
    if has_admin_account():
        return redirect(url_for("login"))
    if request.method == "POST":
        username = request.form.get("username", "").strip().lower()
        password = request.form.get("password", "")
        confirm = request.form.get("confirm_password", "")
        if not valid_username(username):
            flash("Use 3–80 letters, numbers, dots, underscores, or hyphens for the username.", "error")
        elif not password:
            flash("Password is required.", "error")
        elif len(password) > 128:
            flash("Password cannot exceed 128 characters.", "error")
        elif password != confirm:
            flash("The passwords do not match.", "error")
        else:
            with db_cursor() as (_, cur):
                cur.execute("SELECT COUNT(*) AS total FROM user_account WHERE actor_role='ADMIN'")
                if cur.fetchone()["total"]:
                    return redirect(url_for("login"))
                cur.execute("INSERT INTO user_account(username,password_hash,actor_role) VALUES(%s,%s,'ADMIN')",
                            (username, generate_password_hash(password)))
            flash("Administrator account created. Sign in to continue.", "success")
            return redirect(url_for("login"))
    return render_template("setup.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if session.get("account_id"):
        return redirect(url_for("dashboard"))
    if request.method == "POST":
        username = request.form.get("username", "").strip().lower()
        password = request.form.get("password", "")
        with db_cursor() as (_, cur):
            cur.execute("""SELECT account_id,password_hash,is_active FROM user_account
                           WHERE username=%s""", (username,))
            account = cur.fetchone()
        if account and account["is_active"] and check_password_hash(account["password_hash"], password):
            session.clear()
            session["account_id"] = account["account_id"]
            csrf_value()
            return redirect(url_for("dashboard"))
        flash("Username or password is incorrect.", "error")
    return render_template("login.html")


@app.post("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/accounts", methods=["GET", "POST"])
@roles_required("ADMIN")
def accounts():
    if request.method == "POST":
        username = request.form.get("username", "").strip().lower()
        password = request.form.get("password", "")
        role = request.form.get("actor_role", "")
        person_raw = request.form.get("person_id", "").strip()
        try:
            if not valid_username(username):
                raise ValueError("Username must be 3–80 letters, numbers, dots, underscores, or hyphens.")
            if not password:
                raise ValueError("Password is required.")
            if len(password) > 128:
                raise ValueError("Password cannot exceed 128 characters.")
            if role not in {"ADMIN", "AGENT", "OWNER", "TENANT_BUYER"}:
                raise ValueError("Choose a valid actor role.")
            person_id = int(person_raw) if person_raw else None
            with db_cursor() as (_, cur):
                if role == "ADMIN":
                    if person_id is not None:
                        raise ValueError("Admin accounts are not linked to a person profile.")
                else:
                    if person_id is None:
                        raise ValueError("Link this account to a person record.")
                    cur.execute("SELECT person_id FROM user_account WHERE person_id=%s", (person_id,))
                    if cur.fetchone():
                        raise ValueError("This person already has a login account.")
                    table = {"AGENT": "agent", "OWNER": "owner"}.get(role)
                    if table:
                        cur.execute(f"SELECT person_id FROM {table} WHERE person_id=%s", (person_id,))
                        if not cur.fetchone():
                            raise ValueError("The selected person does not match the chosen role.")
                    else:
                        cur.execute("SELECT person_id FROM owner WHERE person_id=%s UNION SELECT person_id FROM agent WHERE person_id=%s",
                                    (person_id, person_id))
                        if cur.fetchone():
                            raise ValueError("Tenant/Buyer accounts cannot be linked to an Owner or Agent profile.")
                cur.execute("INSERT INTO user_account(username,password_hash,actor_role,person_id) VALUES(%s,%s,%s,%s)",
                            (username, generate_password_hash(password), role, person_id))
            flash(f"{ROLE_TITLES[role]} account created.", "success")
        except (ValueError, TypeError) as exc:
            flash(str(exc), "error")
        except Exception as exc:
            flash(f"Could not create account: {exc}", "error")
        return redirect(url_for("accounts"))

    with db_cursor() as (_, cur):
        cur.execute("""SELECT a.account_id,a.username,a.actor_role,a.person_id,a.is_active,p.full_name
                       FROM user_account a LEFT JOIN person p ON p.person_id=a.person_id
                       ORDER BY a.actor_role,a.username""")
        rows = cur.fetchall()
        cur.execute("""SELECT p.person_id,p.full_name,
                              CASE WHEN a.person_id IS NOT NULL THEN 'AGENT'
                                   WHEN o.person_id IS NOT NULL THEN 'OWNER'
                                   WHEN t.person_id IS NOT NULL THEN 'TENANT'
                                   ELSE 'BUYER' END AS profile_type
                       FROM person p
                       LEFT JOIN agent a ON a.person_id=p.person_id
                       LEFT JOIN owner o ON o.person_id=p.person_id
                       LEFT JOIN tenant t ON t.person_id=p.person_id
                       LEFT JOIN user_account ua ON ua.person_id=p.person_id
                       WHERE ua.account_id IS NULL
                       ORDER BY p.full_name LIMIT 1000""")
        people = cur.fetchall()
    return render_template("accounts.html", accounts=rows, people=people)


@app.post("/accounts/<int:account_id>/active")
@roles_required("ADMIN")
def toggle_account(account_id):
    if account_id == g.current_user["account_id"]:
        flash("You cannot deactivate the account you are using.", "error")
        return redirect(url_for("accounts"))
    with db_cursor() as (_, cur):
        cur.execute("UPDATE user_account SET is_active=NOT is_active WHERE account_id=%s", (account_id,))
    flash("Account status updated.", "success")
    return redirect(url_for("accounts"))


@app.route("/")
def dashboard():
    user = g.current_user
    role, person_id = user["actor_role"], user["person_id"]
    if role in {"ADMIN", "TENANT_BUYER"}:
        prop_where, prop_args = ("p.status='AVAILABLE'", []) if role == "TENANT_BUYER" else ("1=1", [])
    else:
        prop_where, prop_args = scope_property(role, person_id)
    with db_cursor() as (_, cur):
        cur.execute(f"SELECT p.status,COUNT(*) AS total FROM property p WHERE {prop_where} GROUP BY p.status", prop_args)
        statuses = {row["status"]: row["total"] for row in cur.fetchall()}
        lease_where = "1=1"
        lease_args = []
        if role == "AGENT":
            lease_where, lease_args = "l.agent_id=%s", [person_id]
        elif role == "OWNER":
            lease_where, lease_args = "p.owner_id=%s", [person_id]
        elif role == "TENANT_BUYER":
            lease_where, lease_args = "l.tenant_id=%s", [person_id]
        cur.execute(f"""SELECT COUNT(*) AS total FROM lease l JOIN property p ON p.property_id=l.property_id
                       WHERE l.status='ACTIVE' AND {lease_where}""", lease_args)
        active_leases = cur.fetchone()["total"]
        cur.execute(f"""SELECT COUNT(*) AS total FROM property p WHERE p.listing_type='FOR_SALE'
                       AND p.status='AVAILABLE' AND {prop_where}""", prop_args)
        sale_listings = cur.fetchone()["total"]
        cash_scope = lease_where
        cur.execute(f"""SELECT COALESCE(SUM(CASE WHEN pay.payment_type='REFUND' THEN -pay.amount ELSE pay.amount END),0) AS total FROM payment pay
                       JOIN lease l ON l.lease_id=pay.lease_id JOIN property p ON p.property_id=l.property_id
                       WHERE pay.status='POSTED'
                       AND pay.payment_date>=DATE_SUB(CURRENT_DATE,INTERVAL DAYOFMONTH(CURRENT_DATE)-1 DAY)
                       AND pay.payment_date<=CURRENT_DATE AND {cash_scope}""", lease_args)
        cash_this_month = cur.fetchone()["total"]
        cur.execute("""SELECT COUNT(*) AS total,COALESCE(SUM(b.balance_due),0) AS balance_due
                       FROM v_invoice_balance b JOIN lease l ON l.lease_id=b.lease_id
                       WHERE b.invoice_status IN ('DUE','PARTIALLY_PAID','OVERDUE')
                         AND (%s='ADMIN'
                              OR (%s='OWNER' AND EXISTS (SELECT 1 FROM property p WHERE p.property_id=l.property_id AND p.owner_id=%s))
                              OR (%s='AGENT' AND l.agent_id=%s)
                              OR (%s='TENANT_BUYER' AND l.tenant_id=%s))""",
                    (role,role,person_id,role,person_id,role,person_id))
        invoice_summary = cur.fetchone()
        cur.execute(f"""SELECT p.property_id,p.title,p.status,p.asking_price,p.listing_type
                       FROM property p WHERE {prop_where}
                       ORDER BY p.created_at DESC,p.property_id DESC LIMIT 8""", prop_args)
        recent_properties = cur.fetchall()
    return render_template("dashboard.html", statuses=statuses, active_leases=active_leases,
                           sale_listings=sale_listings, cash_this_month=cash_this_month,
                           invoice_summary=invoice_summary,recent_properties=recent_properties)


@app.route("/properties")
def properties():
    q = request.args.get("q", "").strip()
    status = request.args.get("status", "").strip()
    role, person_id = g.current_user["actor_role"], g.current_user["person_id"]
    clauses, params = [], []
    if role == "AGENT":
        clauses.append("p.agent_id=%s"); params.append(person_id)
    elif role == "OWNER":
        clauses.append("p.owner_id=%s"); params.append(person_id)
    elif role == "TENANT_BUYER":
        clauses.append("p.status='AVAILABLE'")
    if q:
        clauses.append("(p.title LIKE %s OR p.address LIKE %s)")
        params.extend([f"%{q}%", f"%{q}%"])
    if status in {"AVAILABLE", "LEASED", "UNDER_MAINTENANCE", "SOLD"}:
        clauses.append("p.status=%s"); params.append(status)
    where = " AND ".join(clauses) or "1=1"
    with db_cursor() as (_, cur):
        cur.execute(f"""SELECT p.property_id,p.title,p.address,p.property_type,p.listing_type,p.asking_price,p.status,
                              p.agent_id,p.owner_id,op.full_name AS owner_name,ap.full_name AS agent_name
                       FROM property p JOIN owner o ON o.person_id=p.owner_id JOIN person op ON op.person_id=o.person_id
                       JOIN agent a ON a.person_id=p.agent_id JOIN person ap ON ap.person_id=a.person_id
                       WHERE {where} ORDER BY p.property_id DESC LIMIT 500""", params)
        rows = cur.fetchall()
        agents = []
        if role == "ADMIN":
            cur.execute("SELECT a.person_id,p.full_name FROM agent a JOIN person p USING(person_id) ORDER BY p.full_name")
            agents = cur.fetchall()
    return render_template("properties.html", properties=rows, q=q, selected_status=status, agents=agents)


@app.route("/properties/new", methods=["GET", "POST"])
@roles_required("ADMIN")
def new_property():
    if request.method == "POST":
        try:
            title = request.form["title"].strip()
            address = request.form["address"].strip()
            property_type = request.form["property_type"]
            listing_type = request.form["listing_type"]
            asking_price = float(request.form["asking_price"])
            owner_id = int(request.form["owner_id"])
            agent_id = int(request.form["agent_id"])
            if not title or not address or asking_price <= 0:
                raise ValueError("Enter a title, address, and valid asking price.")
            with db_cursor() as (_, cur):
                cur.execute("SELECT person_id FROM owner WHERE person_id=%s", (owner_id,))
                if not cur.fetchone(): raise ValueError("Select an existing Owner profile.")
                cur.execute("SELECT person_id FROM agent WHERE person_id=%s", (agent_id,))
                if not cur.fetchone(): raise ValueError("Select an existing Agent profile.")
                cur.execute("""INSERT INTO property(title,address,property_type,listing_type,asking_price,status,owner_id,agent_id)
                               VALUES(%s,%s,%s,%s,%s,'AVAILABLE',%s,%s)""",
                            (title,address,property_type,listing_type,asking_price,owner_id,agent_id))
                new_id = cur.lastrowid
                if property_type == "RESIDENTIAL":
                    cur.execute("""INSERT INTO residential_property(property_id,bedrooms,bathrooms,area_sqm,furnished_status)
                                   VALUES(%s,%s,%s,%s,%s)""",
                                (new_id,int(request.form["bedrooms"]),int(request.form["bathrooms"]),float(request.form["area_sqm"]),request.form.get("furnished_status") or None))
                elif property_type == "COMMERCIAL":
                    cur.execute("""INSERT INTO commercial_property(property_id,business_type,floor_area_sqm,parking_spaces)
                                   VALUES(%s,%s,%s,%s)""",
                                (new_id,request.form.get("business_type") or None,float(request.form["floor_area_sqm"]),int(request.form.get("parking_spaces") or 0)))
                else:
                    raise ValueError("Invalid property type.")
            flash(f"Property #{new_id} created.", "success")
            return redirect(url_for("properties"))
        except (ValueError, KeyError, TypeError) as exc:
            flash(str(exc), "error")
        except Exception as exc:
            flash(f"Could not save property: {exc}", "error")
    with db_cursor() as (_, cur):
        cur.execute("SELECT o.person_id,p.full_name FROM owner o JOIN person p USING(person_id) ORDER BY p.full_name LIMIT 500")
        owners = cur.fetchall()
        cur.execute("SELECT a.person_id,p.full_name FROM agent a JOIN person p USING(person_id) ORDER BY p.full_name LIMIT 500")
        agents = cur.fetchall()
    return render_template("property_new.html", owners=owners, agents=agents)


@app.post("/properties/<int:property_id>/listing")
@roles_required("ADMIN", "AGENT")
def update_listing(property_id):
    listing = request.form.get("listing_type")
    try:
        price = float(request.form.get("asking_price", "0"))
        if listing not in {"FOR_SALE", "FOR_RENT"} or price <= 0:
            raise ValueError("Choose a listing type and enter a positive price.")
        with db_cursor() as (_, cur):
            sql = "SELECT property_id FROM property WHERE property_id=%s AND status='AVAILABLE'"
            args = [property_id]
            if g.current_user["actor_role"] == "AGENT":
                sql += " AND agent_id=%s"; args.append(g.current_user["person_id"])
            cur.execute(sql, args)
            if not cur.fetchone():
                abort(404, description="Available property not found in your scope.")
            cur.execute("UPDATE property SET listing_type=%s,asking_price=%s WHERE property_id=%s", (listing,price,property_id))
        flash("Listing updated.", "success")
    except (ValueError, TypeError) as exc:
        flash(str(exc), "error")
    return redirect(url_for("properties"))


@app.post("/properties/<int:property_id>/agent")
@roles_required("ADMIN")
def assign_agent(property_id):
    try:
        agent_id = int(request.form["agent_id"])
        with db_cursor() as (_, cur):
            cur.execute("SELECT person_id FROM agent WHERE person_id=%s", (agent_id,))
            if not cur.fetchone(): raise ValueError("Select an existing Agent profile.")
            cur.execute("SELECT property_id FROM property WHERE property_id=%s", (property_id,))
            if not cur.fetchone(): abort(404)
            cur.execute("UPDATE property SET agent_id=%s WHERE property_id=%s", (agent_id,property_id))
        flash("Agent assignment updated.", "success")
    except (ValueError, KeyError, TypeError) as exc:
        flash(str(exc), "error")
    return redirect(url_for("properties"))


@app.route("/leases", methods=["GET", "POST"])
def leases():
    role, person_id = g.current_user["actor_role"], g.current_user["person_id"]
    if request.method == "POST":
        if role not in {"ADMIN", "AGENT", "TENANT_BUYER"}:
            abort(403)
        try:
            property_id = int(request.form["property_id"])
            tenant_id = person_id if role == "TENANT_BUYER" else int(request.form["tenant_id"])
            start_date, end_date = date.fromisoformat(request.form["start_date"]), date.fromisoformat(request.form["end_date"])
            rent = float(request.form["monthly_rent"])
            deposit, payment_day = float(request.form.get("deposit_amount") or 0), int(request.form.get("payment_day") or 1)
            with db_cursor() as (_, cur):
                cur.execute("SELECT status,listing_type,agent_id FROM property WHERE property_id=%s FOR UPDATE", (property_id,))
                prop = cur.fetchone()
                if not prop or prop["status"] != "AVAILABLE" or prop["listing_type"] != "FOR_RENT":
                    raise ValueError("A lease request requires an AVAILABLE property listed FOR RENT.")
                if role == "AGENT" and prop["agent_id"] != person_id:
                    abort(403)
                cur.execute("SELECT person_id FROM tenant WHERE person_id=%s", (tenant_id,))
                if not cur.fetchone(): raise ValueError("The selected person is not a Tenant.")
                if end_date <= start_date or rent <= 0 or deposit < 0 or not 1 <= payment_day <= 28:
                    raise ValueError("Check the lease dates, rent, deposit, and payment due day.")
                cur.execute("""INSERT INTO lease(start_date,end_date,monthly_rent,deposit_amount,payment_day,status,property_id,tenant_id,agent_id)
                               VALUES(%s,%s,%s,%s,%s,'PENDING',%s,%s,%s)""",
                            (start_date,end_date,rent,deposit,payment_day,property_id,tenant_id,prop["agent_id"]))
            flash("Lease submitted for Admin review.", "success")
        except (ValueError, KeyError, TypeError) as exc:
            flash(str(exc), "error")
        except Exception as exc:
            flash(f"Could not save lease: {exc}", "error")
        return redirect(url_for("leases"))

    where, params = "1=1", []
    if role == "AGENT": where, params = "l.agent_id=%s", [person_id]
    elif role == "OWNER": where, params = "p.owner_id=%s", [person_id]
    elif role == "TENANT_BUYER": where, params = "l.tenant_id=%s", [person_id]
    with db_cursor() as (_, cur):
        cur.execute(f"""SELECT l.lease_id,l.start_date,l.end_date,l.monthly_rent,l.status,l.property_id,
                              p.title,l.tenant_id,tp.full_name AS tenant_name,l.agent_id,l.reviewed_at,ua.username AS reviewed_by
                       FROM lease l JOIN property p ON p.property_id=l.property_id
                       JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
                       LEFT JOIN user_account ua ON ua.account_id=l.reviewed_by_account_id
                       WHERE {where} ORDER BY l.lease_id DESC LIMIT 300""", params)
        rows = cur.fetchall()
        available_properties = []
        tenants = []
        if role in {"ADMIN", "AGENT", "TENANT_BUYER"}:
            clause, pp = "status='AVAILABLE' AND listing_type='FOR_RENT'", []
            if role == "AGENT": clause += " AND agent_id=%s"; pp.append(person_id)
            cur.execute(f"SELECT property_id,title FROM property WHERE {clause} ORDER BY title", pp)
            available_properties = cur.fetchall()
            if role in {"ADMIN", "AGENT"}:
                cur.execute("SELECT t.person_id,p.full_name FROM tenant t JOIN person p USING(person_id) ORDER BY p.full_name LIMIT 1000")
                tenants = cur.fetchall()
    return render_template("leases.html", leases=rows, available_properties=available_properties, tenants=tenants)


@app.post("/leases/<int:lease_id>/status")
@roles_required("ADMIN")
def update_lease_status(lease_id):
    new_status = request.form.get("status")
    if new_status not in {"ACTIVE", "REJECTED", "EXPIRED", "TERMINATED"}:
        abort(400, description="Invalid lease status.")
    try:
        with db_cursor() as (_, cur):
            if new_status in {"ACTIVE", "REJECTED"}:
                cur.execute("""UPDATE lease SET status=%s,reviewed_by_account_id=%s,reviewed_at=NOW()
                               WHERE lease_id=%s AND status='PENDING'""",
                            (new_status,g.current_user["account_id"],lease_id))
            else:
                cur.execute("UPDATE lease SET status=%s WHERE lease_id=%s AND status='ACTIVE'", (new_status,lease_id))
            if cur.rowcount != 1:
                raise ValueError("The lease is not in a state that allows this action.")
        flash("Lease reviewed and updated.", "success")
    except Exception as exc:
        flash(f"Could not update lease: {exc}", "error")
    return redirect(url_for("leases"))


@app.route("/payments", methods=["GET", "POST"])
@roles_required("ADMIN", "OWNER", "TENANT_BUYER")
def payments():
    role, person_id = g.current_user["actor_role"], g.current_user["person_id"]
    if request.method == "POST":
        if role not in {"ADMIN", "TENANT_BUYER"}: abort(403)
        try:
            lease_id, amount = int(request.form["lease_id"]), Decimal(request.form["amount"])
            pay_date = date.fromisoformat(request.form["payment_date"])
            invoice_raw = request.form.get("invoice_id", "").strip()
            invoice_id = int(invoice_raw) if invoice_raw else None
            payment_type, method = request.form.get("payment_type", "RENT"), request.form.get("payment_method") or None
            reference_code = request.form.get("reference_code", "").strip() or None
            idempotency_key = str(UUID(request.form.get("idempotency_key", "")))
            if amount <= 0: raise ValueError("Payment amount must be greater than zero.")
            if pay_date > date.today(): raise ValueError("A posted payment cannot have a future date.")
            if payment_type not in {"RENT", "DEPOSIT", "FEE", "REFUND"}: raise ValueError("Select a valid payment type.")
            if role == "TENANT_BUYER" and payment_type == "REFUND":
                raise ValueError("Only Admin can record a refund.")
            if payment_type == "RENT" and invoice_id is None:
                raise ValueError("Select the rental invoice this rent payment settles.")
            if invoice_id is not None and payment_type not in {"RENT", "REFUND"}:
                raise ValueError("Only rent payments or refunds can be linked to an invoice.")
            with db_cursor() as (_, cur):
                query = "SELECT lease_id FROM lease WHERE lease_id=%s"
                args = [lease_id]
                if role == "TENANT_BUYER": query += " AND tenant_id=%s"; args.append(person_id)
                cur.execute(query + " FOR UPDATE", args)
                if not cur.fetchone(): raise ValueError("The selected lease was not found for this account.")
                invoice_paid = 0
                if invoice_id is not None:
                    cur.execute("""SELECT amount_due,status FROM rental_invoice
                                   WHERE invoice_id=%s AND lease_id=%s FOR UPDATE""", (invoice_id,lease_id))
                    invoice = cur.fetchone()
                    if not invoice or invoice["status"] != "ISSUED":
                        raise ValueError("The selected invoice does not belong to this lease or is void.")
                    cur.execute("""SELECT COALESCE(SUM(CASE WHEN payment_type='RENT' THEN amount
                                                        WHEN payment_type='REFUND' THEN -amount ELSE 0 END),0) AS paid
                                   FROM payment WHERE invoice_id=%s AND status='POSTED'""", (invoice_id,))
                    invoice_paid = cur.fetchone()["paid"]
                    balance = max(invoice["amount_due"]-invoice_paid,0)
                    if payment_type == "RENT" and amount > balance:
                        raise ValueError(f"Payment exceeds the invoice balance ({balance:,.0f} VND).")
                    if payment_type == "REFUND" and amount > invoice_paid:
                        raise ValueError("Refund exceeds the amount previously paid on this invoice.")
                cur.execute("""SELECT payment_id FROM payment
                               WHERE lease_id=%s AND invoice_id <=> %s AND payment_date=%s AND amount=%s
                                 AND payment_type=%s AND payment_method <=> %s AND reference_code <=> %s
                                 AND status='POSTED' LIMIT 1""",
                            (lease_id,invoice_id,pay_date,amount,payment_type,method,reference_code))
                if cur.fetchone():
                    raise ValueError("An identical payment is already recorded. Check the transaction reference before retrying.")
                cur.execute("""INSERT INTO payment(lease_id,invoice_id,payment_date,amount,payment_type,
                                                   payment_method,reference_code,idempotency_key)
                               VALUES(%s,%s,%s,%s,%s,%s,%s,%s)""",
                            (lease_id,invoice_id,pay_date,amount,payment_type,method,reference_code,idempotency_key))
            flash("Payment recorded.", "success")
        except (ValueError, KeyError, TypeError) as exc:
            flash(str(exc), "error")
        except pymysql.err.IntegrityError as exc:
            if exc.args and exc.args[0] == 1062:
                flash("This payment or transaction reference was already recorded.", "error")
            else:
                flash(f"Could not record payment: {exc}", "error")
        except Exception as exc:
            flash(f"Could not record payment: {exc}", "error")
        return redirect(url_for("payments"))

    with db_cursor() as (_, cur):
        leases, where, args = [], "1=1", []
        if role == "TENANT_BUYER": where, args = "l.tenant_id=%s", [person_id]
        elif role == "OWNER": where, args = "p.owner_id=%s", [person_id]
        cur.execute(f"""SELECT l.lease_id,l.status,p.title,tp.full_name AS tenant_name
                       FROM lease l JOIN property p ON p.property_id=l.property_id
                       JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
                       WHERE {where} ORDER BY (l.status='ACTIVE') DESC,l.lease_id DESC LIMIT 500""", args)
        leases = cur.fetchall()
        invoice_where, invoice_args = "b.balance_due>0 AND b.status='ISSUED'", []
        if role == "TENANT_BUYER": invoice_where += " AND l.tenant_id=%s"; invoice_args.append(person_id)
        elif role == "OWNER": invoice_where += " AND p.owner_id=%s"; invoice_args.append(person_id)
        cur.execute(f"""SELECT b.invoice_id,b.lease_id,b.period_start,b.period_end,b.due_date,
                              b.amount_due,b.balance_due,b.invoice_status,p.title,tp.full_name AS tenant_name
                       FROM v_invoice_balance b JOIN lease l ON l.lease_id=b.lease_id
                       JOIN property p ON p.property_id=l.property_id
                       JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
                       WHERE {invoice_where} ORDER BY b.due_date,b.invoice_id LIMIT 500""", invoice_args)
        invoices = cur.fetchall()
        cur.execute(f"""SELECT pay.payment_id,pay.payment_date,pay.amount,pay.payment_type,pay.payment_method,
                              pay.status,pay.lease_id,pay.invoice_id,pay.reference_code,p.title,tp.full_name AS tenant_name
                       FROM payment pay JOIN lease l ON l.lease_id=pay.lease_id JOIN property p ON p.property_id=l.property_id
                       JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
                       WHERE {where.replace('l.', 'l.')} ORDER BY pay.payment_date DESC,pay.payment_id DESC LIMIT 300""", args)
        recent_payments = cur.fetchall()
    return render_template("payments.html", leases=leases, recent_payments=recent_payments,
                           invoices=invoices,idempotency_key=str(uuid4()),today=date.today().isoformat(),
                           can_record=role in {"ADMIN", "TENANT_BUYER"})


@app.route("/invoices", methods=["GET", "POST"])
@roles_required("ADMIN", "AGENT", "OWNER", "TENANT_BUYER")
def invoices():
    role, person_id = g.current_user["actor_role"], g.current_user["person_id"]
    if request.method == "POST":
        if role != "ADMIN": abort(403)
        with db_cursor() as (_, cur):
            call_procedure(cur, "CALL sp_generate_rental_invoices(%s)", (date.today(),))
            call_procedure(cur, "CALL sp_refresh_notifications(%s)", (date.today(),))
        flash("Rental invoices generated through today; balances and notices are refreshed.", "success")
        return redirect(url_for("invoices"))

    where, args = "1=1", []
    if role == "AGENT": where, args = "l.agent_id=%s", [person_id]
    elif role == "OWNER": where, args = "p.owner_id=%s", [person_id]
    elif role == "TENANT_BUYER": where, args = "l.tenant_id=%s", [person_id]
    with db_cursor() as (_, cur):
        call_procedure(cur, "CALL sp_refresh_notifications(%s)", (date.today(),))
        cur.execute(f"""SELECT b.invoice_id,b.lease_id,b.period_start,b.period_end,b.issue_date,b.due_date,
                              b.amount_due,b.amount_paid,b.balance_due,b.invoice_status,
                              p.property_id,p.title,tp.full_name AS tenant_name
                       FROM v_invoice_balance b JOIN lease l ON l.lease_id=b.lease_id
                       JOIN property p ON p.property_id=l.property_id
                       JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
                       WHERE {where} ORDER BY b.due_date DESC,b.invoice_id DESC LIMIT 1000""", args)
        rows = cur.fetchall()
    return render_template("invoices.html", invoices=rows, can_generate=role == "ADMIN")


@app.route("/notifications")
@roles_required("ADMIN", "AGENT", "OWNER", "TENANT_BUYER")
def notifications():
    with db_cursor() as (_, cur):
        call_procedure(cur, "CALL sp_refresh_notifications(%s)", (date.today(),))
        cur.execute("""SELECT notification_id,notification_type,title,message,is_read,created_at
                       FROM notification WHERE account_id=%s
                       ORDER BY is_read,created_at DESC,notification_id DESC LIMIT 300""",
                    (g.current_user["account_id"],))
        rows = cur.fetchall()
    return render_template("notifications.html", notifications=rows)


@app.post("/notifications/<int:notification_id>/read")
@roles_required("ADMIN", "AGENT", "OWNER", "TENANT_BUYER")
def mark_notification_read(notification_id):
    with db_cursor() as (_, cur):
        cur.execute("UPDATE notification SET is_read=TRUE WHERE notification_id=%s AND account_id=%s",
                    (notification_id,g.current_user["account_id"]))
    return redirect(url_for("notifications"))


@app.route("/sales", methods=["GET", "POST"])
@roles_required("ADMIN", "AGENT", "OWNER", "TENANT_BUYER")
def sales():
    role, person_id = g.current_user["actor_role"], g.current_user["person_id"]
    if request.method == "POST":
        if role not in {"ADMIN", "AGENT"}: abort(403)
        try:
            property_id = int(request.form["property_id"])
            buyer_id = int(request.form["buyer_id"])
            sale_price = Decimal(request.form["sale_price"])
            if not sale_price.is_finite() or sale_price <= 0: raise ValueError("Sale price must be greater than zero.")
            with db_cursor() as (_, cur):
                cur.execute("""SELECT p.status,p.listing_type,p.agent_id,a.commission_rate
                               FROM property p JOIN agent a ON a.person_id=p.agent_id
                               WHERE p.property_id=%s FOR UPDATE""", (property_id,))
                prop = cur.fetchone()
                if not prop or prop["status"] != "AVAILABLE" or prop["listing_type"] != "FOR_SALE":
                    raise ValueError("Choose an available property listed for sale.")
                if role == "AGENT" and prop["agent_id"] != person_id:
                    abort(403)
                cur.execute("SELECT person_id FROM tenant WHERE person_id=%s", (buyer_id,))
                if not cur.fetchone(): raise ValueError("Select an existing Buyer/Tenant profile.")
                cur.execute("""INSERT INTO sale_transaction(property_id,buyer_id,agent_id,sale_price,
                                                               commission_rate_at_sale,contract_date,status)
                               VALUES(%s,%s,%s,%s,%s,CURRENT_DATE,'PENDING')""",
                            (property_id,buyer_id,prop["agent_id"],sale_price,prop["commission_rate"]))
            flash("Sale submitted for Admin review.", "success")
        except (ValueError, KeyError, TypeError) as exc:
            flash(str(exc), "error")
        except pymysql.err.IntegrityError as exc:
            if exc.args and exc.args[0] == 1062:
                flash("This property already has a pending or approved sale.", "error")
            else:
                flash(f"Could not submit sale: {exc}", "error")
        except Exception as exc:
            flash(f"Could not submit sale: {exc}", "error")
        return redirect(url_for("sales"))

    where, args = "1=1", []
    if role == "AGENT": where, args = "s.agent_id=%s", [person_id]
    elif role == "OWNER": where, args = "p.owner_id=%s", [person_id]
    elif role == "TENANT_BUYER": where, args = "s.buyer_id=%s", [person_id]
    with db_cursor() as (_, cur):
        cur.execute(f"""SELECT s.sale_id,s.property_id,s.sale_price,s.commission_rate_at_sale,s.commission_amount,
                              s.contract_date,s.closing_date,s.status,s.agent_id,s.buyer_id,s.reviewed_at,
                              p.title,b.full_name AS buyer_name,ap.full_name AS agent_name,ua.username AS reviewed_by
                       FROM sale_transaction s JOIN property p ON p.property_id=s.property_id
                       JOIN person b ON b.person_id=s.buyer_id
                       JOIN agent a ON a.person_id=s.agent_id JOIN person ap ON ap.person_id=a.person_id
                       LEFT JOIN user_account ua ON ua.account_id=s.reviewed_by_account_id
                       WHERE {where} ORDER BY s.sale_id DESC LIMIT 500""", args)
        rows = cur.fetchall()
        available_properties, buyers = [], []
        if role in {"ADMIN", "AGENT"}:
            clause, pp = "status='AVAILABLE' AND listing_type='FOR_SALE'", []
            if role == "AGENT": clause += " AND agent_id=%s"; pp.append(person_id)
            cur.execute(f"SELECT property_id,title,asking_price FROM property WHERE {clause} ORDER BY title", pp)
            available_properties = cur.fetchall()
            cur.execute("SELECT t.person_id,p.full_name FROM tenant t JOIN person p USING(person_id) ORDER BY p.full_name LIMIT 1000")
            buyers = cur.fetchall()
    return render_template("sales.html", sales=rows, properties=available_properties, buyers=buyers,
                           can_submit=role in {"ADMIN", "AGENT"}, can_review=role == "ADMIN")


@app.post("/sales/<int:sale_id>/status")
@roles_required("ADMIN")
def update_sale_status(sale_id):
    new_status = request.form.get("status")
    if new_status not in {"APPROVED", "CLOSED", "REJECTED", "CANCELLED"}:
        abort(400, description="Invalid sale status.")
    try:
        with db_cursor() as (_, cur):
            if new_status in {"APPROVED", "REJECTED"}:
                cur.execute("""UPDATE sale_transaction SET status=%s,reviewed_by_account_id=%s,reviewed_at=NOW()
                               WHERE sale_id=%s AND status='PENDING'""",
                            (new_status,g.current_user["account_id"],sale_id))
            elif new_status == "CLOSED":
                cur.execute("""UPDATE sale_transaction SET status='CLOSED',closing_date=CURRENT_DATE,
                                   reviewed_by_account_id=%s,reviewed_at=NOW()
                               WHERE sale_id=%s AND status='APPROVED'""",
                            (g.current_user["account_id"],sale_id))
            else:
                cur.execute("""UPDATE sale_transaction SET status='CANCELLED',reviewed_by_account_id=%s,reviewed_at=NOW()
                               WHERE sale_id=%s AND status IN ('PENDING','APPROVED')""",
                            (g.current_user["account_id"],sale_id))
            if cur.rowcount != 1: raise ValueError("The sale is not in a state that allows this action.")
        flash("Sale status updated.", "success")
    except Exception as exc:
        flash(f"Could not update sale: {exc}", "error")
    return redirect(url_for("sales"))


@app.route("/maintenance", methods=["GET", "POST"])
def maintenance():
    role, person_id = g.current_user["actor_role"], g.current_user["person_id"]
    if request.method == "POST":
        if role not in {"ADMIN", "AGENT", "TENANT_BUYER"}: abort(403)
        try:
            lease_id = int(request.form["lease_id"])
            description = request.form["description"].strip()
            estimated = float(request.form["estimated_cost"]) if request.form.get("estimated_cost") else None
            if not description or (estimated is not None and estimated < 0): raise ValueError("Enter a description and a valid estimated cost.")
            with db_cursor() as (_, cur):
                query = "SELECT lease_id FROM lease WHERE lease_id=%s AND status='ACTIVE'"
                args = [lease_id]
                if role == "AGENT": query += " AND agent_id=%s"; args.append(person_id)
                elif role == "TENANT_BUYER": query += " AND tenant_id=%s"; args.append(person_id)
                cur.execute(query, args)
                if not cur.fetchone(): raise ValueError("Choose an active lease assigned to this account.")
                cur.execute("INSERT INTO maintenance_request(lease_id,description,report_date,estimated_cost) VALUES(%s,%s,CURRENT_DATE,%s)",
                            (lease_id,description,estimated))
            flash("Maintenance request created.", "success")
        except (ValueError, KeyError, TypeError) as exc:
            flash(str(exc), "error")
        except Exception as exc:
            flash(f"Could not create request: {exc}", "error")
        return redirect(url_for("maintenance"))

    where, args = "1=1", []
    if role == "AGENT": where, args = "l.agent_id=%s", [person_id]
    elif role == "OWNER": where, args = "p.owner_id=%s", [person_id]
    elif role == "TENANT_BUYER": where, args = "l.tenant_id=%s", [person_id]
    with db_cursor() as (_, cur):
        cur.execute(f"""SELECT m.request_id,m.description,m.report_date,m.estimated_cost,m.actual_cost,m.status,
                              l.lease_id,p.property_id,p.title,tp.full_name AS tenant_name
                       FROM maintenance_request m JOIN lease l ON l.lease_id=m.lease_id JOIN property p ON p.property_id=l.property_id
                       JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
                       WHERE {where} ORDER BY m.report_date DESC,m.request_id DESC LIMIT 500""", args)
        rows = cur.fetchall()
        active_leases = []
        if role in {"ADMIN", "AGENT", "TENANT_BUYER"}:
            clause, params = "l.status='ACTIVE'", []
            if role == "AGENT": clause += " AND l.agent_id=%s"; params.append(person_id)
            elif role == "TENANT_BUYER": clause += " AND l.tenant_id=%s"; params.append(person_id)
            cur.execute(f"""SELECT l.lease_id,p.title,tp.full_name AS tenant_name FROM lease l
                           JOIN property p ON p.property_id=l.property_id JOIN tenant t ON t.person_id=l.tenant_id
                           JOIN person tp ON tp.person_id=t.person_id WHERE {clause} ORDER BY l.lease_id DESC LIMIT 500""", params)
            active_leases = cur.fetchall()
    return render_template("maintenance.html", requests=rows, active_leases=active_leases,
                           can_create=role in {"ADMIN", "AGENT", "TENANT_BUYER"}, can_manage=role == "ADMIN")


@app.post("/maintenance/<int:request_id>/status")
@roles_required("ADMIN")
def update_maintenance_status(request_id):
    new_status = request.form.get("status")
    if new_status not in {"PENDING", "IN_PROGRESS", "COMPLETED", "CANCELLED"}:
        abort(400, description="Invalid maintenance status.")
    try:
        with db_cursor() as (_, cur):
            cur.execute("UPDATE maintenance_request SET status=%s,resolved_at=IF(%s='COMPLETED',NOW(),NULL) WHERE request_id=%s",
                        (new_status,new_status,request_id))
            if cur.rowcount != 1: raise ValueError("Maintenance request not found.")
        flash("Maintenance request updated.", "success")
    except Exception as exc:
        flash(f"Could not update request: {exc}", "error")
    return redirect(url_for("maintenance"))


@app.errorhandler(Exception)
def handle_error(error):
    if isinstance(error, HTTPException):
        return render_template("error.html", error=error.description), error.code
    app.logger.exception("Request failed")
    return render_template("error.html", error="A server error occurred."), 500


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.getenv("PORT", "5000")), debug=False)
