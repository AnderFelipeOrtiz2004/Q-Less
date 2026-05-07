import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../services/auth.js';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './register.html',
  styleUrl: './register.css'
})
export class RegisterComponent {
  user = {
    name: '',
    email: '',
    telefono: '',
    password: '',
    password_confirmation: ''
  };
  errors: { type: string; message: string }[] = [];
  isLoading = false;

  constructor(private authService: AuthService, private router: Router) {}

  clearErrors(): void {
    this.errors = [];
  }

  addError(type: string, message: string): void {
    this.errors.push({ type, message });
  }

  validateForm(): boolean {
    this.clearErrors();
    let isValid = true;

    if (!this.user.name.trim()) {
      this.addError('danger', 'El nombre es requerido');
      isValid = false;
    }

    if (!this.user.email.trim()) {
      this.addError('danger', 'El email es requerido');
      isValid = false;
    } else if (!this.isValidEmail(this.user.email)) {
      this.addError('warning', 'Formato de email invalido');
      isValid = false;
    }

    if (!this.user.telefono.trim()) {
      this.addError('danger', 'El telefono es requerido');
      isValid = false;
    }

    if (!this.user.password.trim() || this.user.password.length < 8) {
      this.addError('danger', 'La contrasena debe tener al menos 8 caracteres');
      isValid = false;
    }

    if (this.user.password !== this.user.password_confirmation) {
      this.addError('danger', 'Las contrasenas no coinciden');
      isValid = false;
    }

    return isValid;
  }

  isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  registrar(): void {
    if (!this.validateForm()) return;

    this.isLoading = true;
    this.clearErrors();

    this.authService.register(this.user).subscribe({
      next: (res: any) => {
        this.isLoading = false;
        if (res?.status === true && res?.token) {
          if (res.user?.name) localStorage.setItem('user_name', res.user.name);
          if (res.user?.id) localStorage.setItem('user_id', String(res.user.id));
          if (res.user?.rol) localStorage.setItem('user_role', res.user.rol);

          this.authService.saveToken(res.token);
          this.addError('success', 'Registro exitoso. Redirigiendo...');

          setTimeout(() => {
            this.router.navigate(['/home']);
          }, 2000);
        } else {
          this.addError('danger', 'La respuesta del servidor no fue valida.');
        }
      },
      error: (err: any) => {
        this.isLoading = false;
        if (err?.status === 422) {
          const serverErrors = err.error.errors;
          if (serverErrors?.email) {
            this.addError('danger', 'Este email ya esta registrado.');
          } else if (serverErrors?.telefono) {
            this.addError('danger', 'El telefono es obligatorio.');
          } else if (serverErrors?.password) {
            this.addError('danger', 'La contrasena no cumple con los requisitos.');
          } else {
            this.addError('danger', 'Error de validacion en los datos.');
          }
        } else {
          this.addError('danger', 'Error de conexion con el servidor.');
        }
      }
    });
  }
}
