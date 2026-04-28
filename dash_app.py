import dash
from dash import html, dcc, Input, Output, State, dash_table
import csv
import subprocess
import os
import json

# Carregar dados
def load_data():
    data = []
    try:
        with open('data/apps_output.csv', 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                data.append(row)
        return data
    except FileNotFoundError:
        # Fallback para dados de exemplo
        return [
            {'AppName': '7zip 25', 'appversion': '', 'LatestVersion': '25.01', 'Website': 'https://www.7-zip.org/', 'InstalledVersion': '25', 'Status': 'UpdateAvailable', 'License': 'Free', 'Observation': ''},
            {'AppName': 'notepad++', 'appversion': '8.9', 'LatestVersion': '8.9.1', 'Website': 'https://notepad-plus-plus.org/downloads/', 'InstalledVersion': '8.9', 'Status': 'UpdateAvailable', 'License': 'Free', 'Observation': ''}
        ]

# Inicializar app
app = dash.Dash(__name__, external_stylesheets=['https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css'])

# Layout
app.layout = html.Div([
    html.H1('SCCM Application Status', className='text-center my-4'),
    
    # Controles
    html.Div([
        dcc.Upload(
            id='upload-data',
            children=html.Div(['Arraste e solte ou clique para selecionar um arquivo CSV']),
            style={
                'width': '100%',
                'height': '60px',
                'lineHeight': '60px',
                'borderWidth': '1px',
                'borderStyle': 'dashed',
                'borderRadius': '5px',
                'textAlign': 'center',
                'margin': '10px'
            },
            multiple=False
        ),
        html.Div([
            html.Label('Filtrar:'),
            dcc.Input(id='search-input', type='text', placeholder='Nome, versão ou status...', className='form-control'),
        ], className='form-group'),
        html.Div([
            html.Label('Status:'),
            dcc.Dropdown(
                id='status-filter',
                options=[
                    {'label': 'Todos', 'value': ''},
                    {'label': 'UpdateAvailable', 'value': 'UpdateAvailable'},
                    {'label': 'UpToDate', 'value': 'UpToDate'},
                    {'label': 'Unknown', 'value': 'Unknown'}
                ],
                value='',
                className='form-control'
            ),
        ], className='form-group'),
        html.Div([
            html.Label('Licença:'),
            dcc.Dropdown(
                id='license-filter',
                options=[
                    {'label': 'Todas', 'value': ''},
                    {'label': 'Licensed', 'value': 'Licensed'},
                    {'label': 'Free', 'value': 'Free'}
                ],
                value='',
                className='form-control'
            ),
        ], className='form-group'),
        html.Button('Atualizar Agora', id='update-btn', className='btn btn-primary'),
        html.Div(id='last-update', children='Última Verificação: --/--/---- --:--:--'),
    ], className='row'),
    
    # Tabela
    dash_table.DataTable(
        id='apps-table',
        columns=[
            {'name': '#', 'id': 'index'},
            {'name': 'Aplicações', 'id': 'AppName'},
            {'name': 'Versão App', 'id': 'appversion'},
            {'name': 'Última Versão', 'id': 'LatestVersion'},
            {'name': 'Status', 'id': 'Status'},
            {'name': 'Licença', 'id': 'License'},
            {'name': 'Observação', 'id': 'Observation'},
            {'name': 'Ações', 'id': 'actions', 'presentation': 'markdown'}
        ],
        data=[],
        style_table={'overflowX': 'auto'},
        style_cell={'textAlign': 'left'},
        style_header={'backgroundColor': 'rgb(230, 230, 230)', 'fontWeight': 'bold'},
        page_size=10
    ),
    
    # Gráfico (removido por enquanto)
    # dcc.Graph(id='status-chart'),
    
    # Modal de edição (simplificado)
    html.Div([
        dcc.Modal(
            id='edit-modal',
            children=[
                html.H2('Editar Aplicação'),
                dcc.Input(id='edit-app-name', type='text', placeholder='Aplicação'),
                dcc.Input(id='edit-observation', type='text', placeholder='Observação'),
                html.Button('Salvar', id='save-edit', className='btn btn-primary'),
                html.Button('Cancelar', id='cancel-edit', className='btn btn-secondary'),
            ]
        )
    ])
])

# Callbacks
@app.callback(
    Output('apps-table', 'data'),
    Input('search-input', 'value'),
    Input('status-filter', 'value'),
    Input('license-filter', 'value'),
    Input('upload-data', 'contents'),
    State('upload-data', 'filename')
)
def update_table(search, status_filter, license_filter, contents, filename):
    data = load_data()
    
    # Aplicar filtros
    if search:
        data = [row for row in data if any(search.lower() in str(val).lower() for val in row.values())]
    if status_filter:
        data = [row for row in data if row.get('Status') == status_filter]
    if license_filter:
        data = [row for row in data if row.get('License') == license_filter]
    
    # Adicionar coluna de ações
    for row in data:
        row['actions'] = '[Editar](#)'
        row['index'] = str(data.index(row) + 1)
    
    return data

@app.callback(
    Output('last-update', 'children'),
    Input('update-btn', 'n_clicks')
)
def run_update(n_clicks):
    if n_clicks:
        # Executar PowerShell
        result = subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-File", "apps_update.ps1"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return 'Última Verificação: Atualizada com sucesso'
        else:
            return f'Erro: {result.stderr}'
    return 'Última Verificação: --/--/---- --:--:--'

if __name__ == '__main__':
    app.run_server(debug=True)